class_name Player3D
extends CharacterBody3D

## Player3D - Kontroler gracza 3D (Kosmiczny Robot) z płynnym obrotem, przechyłem, stawianiem bomb i reakcją na zniszczenie

signal exploded

const BOMB_SCENE: PackedScene = preload("res://assets/3d/bomb_3d.tscn")

@export_group("Ruch")
@export var speed: float = 7.0
@export var acceleration: float = 14.0
@export var rotation_speed: float = 12.0
@export var arena_radius: float = 16.0

@export_group("Umiejętności")
@export var bomb_cooldown_time: float = 0.5 ## Szybki cooldown (0.5s) dla natychmiastowej responsywności

@onready var visuals: Node3D = $Visuals
@onready var shield_mesh: MeshInstance3D = get_node_or_null("ShieldMesh")

var start_position: Vector3
var _speed_multiplier: float = 1.0
var _boost_timer: float = 0.0
var _is_frozen: bool = false
var _is_invincible: bool = false
var _is_shield_active: bool = false
var _shield_energy: float = 100.0
var _bomb_cooldown: float = 0.0
var _space_was_pressed: bool = false

func _ready() -> void:
	add_to_group("player")
	start_position = global_position
	if shield_mesh:
		shield_mesh.visible = false


func _physics_process(delta: float) -> void:
	if _is_frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return
		
	# Odliczanie czasu odnowienia bomby
	if _bomb_cooldown > 0.0:
		_bomb_cooldown -= delta
		
	# Obsługa tarczy gracza (PPM / Prawy Klawisz Myszy / Lewy Shift / Klawisz Q)
	var shield_requested: bool = (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		or Input.is_key_pressed(KEY_SHIFT)
		or Input.is_physical_key_pressed(KEY_SHIFT)
		or Input.is_key_pressed(KEY_Q)
		or Input.is_key_pressed(KEY_F)
	)
	
	if shield_requested:
		activate_shield()
	else:
		deactivate_shield()
		
	# Efekt pulsowania aktywnej tarczy
	if _is_shield_active and shield_mesh:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.06
		shield_mesh.scale = Vector3.ONE * pulse
		
	# Bezpośrednie odpytywanie klawiatury w każdej klatce fizyki (100% pewności wykrycia spacji)
	var space_is_down: bool = (
		Input.is_key_pressed(KEY_SPACE)
		or Input.is_physical_key_pressed(KEY_SPACE)
		or Input.is_action_pressed("ui_accept")
		or Input.is_action_pressed("ui_select")
		or Input.is_key_pressed(KEY_B)
		or Input.is_key_pressed(KEY_E)
	)
	
	if space_is_down:
		if not _space_was_pressed and _bomb_cooldown <= 0.0:
			drop_bomb()
	_space_was_pressed = space_is_down
		
	# Obsługa czasu dopalacza
	if _boost_timer > 0.0:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_speed_multiplier = 1.0
			
	# Pobranie kierunku wejścia (WASD / Strzałki)
	var input_vector: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var target_dir := Vector3(input_vector.x, 0.0, input_vector.y)
	
	# Podczas używania tarczy gracz porusza się nieco wolniej (stabilność obrony)
	var shield_speed_mod: float = 0.75 if _is_shield_active else 1.0
	
	if target_dir.length_squared() > 1.0:
		target_dir = target_dir.normalized()
		
	var target_velocity := target_dir * (speed * _speed_multiplier * shield_speed_mod)
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	move_and_slide()
	
	# Ograniczenie pozycji do okręgu areny
	var flat_pos := Vector2(global_position.x, global_position.z)
	if flat_pos.length() > arena_radius:
		flat_pos = flat_pos.normalized() * arena_radius
		global_position.x = flat_pos.x
		global_position.z = flat_pos.y
		
	# Płynne obracanie modelu w stronę kierunku ruchu
	if visuals != null and target_dir.length_squared() > 0.01:
		var target_angle := atan2(target_dir.x, target_dir.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, rotation_speed * delta)
		# Lekki przechył do przodu podczas biegu
		visuals.rotation.x = lerp_angle(visuals.rotation.x, deg_to_rad(8.0), 10.0 * delta)
	elif visuals != null:
		visuals.rotation.x = lerp_angle(visuals.rotation.x, 0.0, 10.0 * delta)


func _input(event: InputEvent) -> void:
	if _is_frozen:
		return
		
	# Dodatkowe wyłapanie zdarzenia klawiatury dla natychmiastowej reakcji
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE or event.keycode == KEY_B or event.keycode == KEY_E:
			if _bomb_cooldown <= 0.0:
				drop_bomb()
	elif event.is_action_pressed("ui_select") or event.is_action_pressed("ui_accept"):
		if _bomb_cooldown <= 0.0:
			drop_bomb()


## Stawia bombę w miejscu pobytu gracza
func drop_bomb() -> void:
	if _bomb_cooldown > 0.0 or _is_frozen:
		return
		
	_bomb_cooldown = bomb_cooldown_time
	var bomb: Node = BOMB_SCENE.instantiate()
	if bomb == null:
		push_error("Nie udało się załadować sceny bomby!")
		return
		
	# Obliczenie pozycji postawienia bomby (na poziomie podłoża pod robotem)
	var spawn_pos := Vector3(global_position.x, 0.0, global_position.z)
	
	# Dodanie do sceny głównej
	var target_parent := get_parent()
	if target_parent == null:
		target_parent = get_tree().current_scene
	target_parent.add_child(bomb)
	
	if bomb is Node3D:
		(bomb as Node3D).global_position = spawn_pos
		
	if "is_player_bomb" in bomb:
		bomb.set("is_player_bomb", true)
		
	if bomb.has_method("start_fuse"):
		bomb.call("start_fuse", 1.8)
		
	print("💣 BOMB DROPPED! Bomba postawiona na pozycji: %s!" % str(spawn_pos))
	
	# Soczysty efekt ugięcia i wyskoku robota przy zrzucie bomby
	if visuals:
		var bounce_tween := create_tween()
		bounce_tween.tween_property(visuals, "scale", Vector3(1.3, 0.7, 1.3), 0.08)
		bounce_tween.tween_property(visuals, "scale", Vector3.ONE, 0.14)


## Zwiększa prędkość gracza na określony czas (np. bonus po zebraniu gwiazdek)
func apply_speed_boost(multiplier: float = 1.5, duration: float = 3.0) -> void:
	_speed_multiplier = multiplier
	_boost_timer = duration


## Zniszczenie gracza przez UFO z soczystą animacją wybuchu i odrodzeniem
func explode() -> void:
	if _is_invincible or _is_frozen:
		return
		
	_is_invincible = true
	_is_frozen = true
	exploded.emit()
	
	# Efekt wybuchu (czerwony błysk, powiększenie i zniknięcie)
	if visuals:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(visuals, "scale", Vector3(2.2, 2.2, 2.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(visuals, "rotation:y", visuals.rotation.y + PI * 2, 0.25)
		await tween.finished
		visuals.visible = false
		
	# Krótka pauza i respawn na pozycji startowej
	await get_tree().create_timer(0.4).timeout
	global_position = start_position
	velocity = Vector3.ZERO
	_is_frozen = false
	
	# Miganie nietykalności (I-frames) po odrodzeniu
	if visuals:
		visuals.scale = Vector3.ONE
		visuals.visible = true
		for i in range(6):
			visuals.visible = false
			await get_tree().create_timer(0.12).timeout
			visuals.visible = true
			await get_tree().create_timer(0.12).timeout
			
	_is_invincible = false


## Sprawdza czy gracz jest aktualnie nietykalny
func is_invincible() -> bool:
	return _is_invincible or _is_shield_active


## Aktywuje tarczę plazmową chroniącą przed laserami
func activate_shield() -> void:
	if _is_frozen or _is_invincible:
		return
	if not _is_shield_active:
		_is_shield_active = true
		if shield_mesh:
			shield_mesh.visible = true
			var tween := create_tween()
			shield_mesh.scale = Vector3(0.3, 0.3, 0.3)
			tween.tween_property(shield_mesh, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Wyłącza tarczę plazmową
func deactivate_shield() -> void:
	if _is_shield_active:
		_is_shield_active = false
		if shield_mesh:
			shield_mesh.visible = false


## Sprawdza czy tarcza jest aktualnie uniesiona
func is_shield_active() -> bool:
	return _is_shield_active


## Odbija / pochłania pocisk laserowy wroga
func block_projectile() -> void:
	print("🛡️✨ TARCZA ZABLOKOWAŁA LASER UFO!")
	if shield_mesh:
		var flash_tween := create_tween()
		flash_tween.tween_property(shield_mesh, "scale", Vector3(1.3, 1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		flash_tween.tween_property(shield_mesh, "scale", Vector3.ONE, 0.12)


## Zatrzymuje gracza (np. ekran wygranej)
func freeze() -> void:
	_is_frozen = true
	deactivate_shield()


## Wznawia ruch gracza
func unfreeze() -> void:
	_is_frozen = false
