class_name UFO3D
extends Area3D

## UFO3D - Kosmiczny spodek wroga w pełnym 3D.
## Posiada ciągły pościg, ostrzał laserowy gracza (jak w 2D),
## powiększa się o 15% po pokonaniu gracza, a po najechaniu na bombę
## zmniejsza się o 15% i przyspiesza o 15%!

signal hit_player
signal exploded
signal size_changed(new_scale_factor: float)

const LASER_SCENE: PackedScene = preload("res://assets/3d/laser_enemy_3d.tscn")

@export_group("Poruszanie się i Pościg")
@export var base_speed: float = 3.6
@export var chase_acceleration: float = 6.5
@export var hover_amplitude: float = 0.2
@export var hover_frequency: float = 3.0
@export var attack_distance: float = 1.6

@export_group("Ostrzał Laserowy (Wersja 2D)")
@export var can_shoot: bool = true ## Czy UFO aktywnie strzela do gracza
@export var shoot_interval: float = 3.0 ## Odstęp czasowy między strzałami (strzał co 3 sekundy)

@onready var visuals: Node3D = $Visuals
@onready var thruster_light: OmniLight3D = $ThrusterLight
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")

var current_scale_multiplier: float = 1.0
var _initial_base_speed: float = 3.6
var _initial_chase_accel: float = 6.5

var _target: Node3D = null
var _current_velocity := Vector3.ZERO
var _base_y: float = 0.65
var _time: float = 0.0
var _speed_multiplier: float = 1.0
var _is_frozen: bool = false
var _hit_cooldown: float = 0.0
var _bomb_hit_cooldown: float = 0.0
var _shoot_timer: float = 0.0
var is_exploding: bool = false

func _ready() -> void:
	_base_y = position.y
	_initial_base_speed = base_speed
	_initial_chase_accel = chase_acceleration
	add_to_group("ufos")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if _is_frozen or is_exploding:
		return
		
	_time += delta
	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta
	if _bomb_hit_cooldown > 0.0:
		_bomb_hit_cooldown -= delta
	
	# Płynne unoszenie się (hovering) spodka
	var hover_offset := sin(_time * hover_frequency) * hover_amplitude
	
	# Sprawdzanie czy w pobliżu nie ma bomby (detekcja najechania na bombę)
	if _bomb_hit_cooldown <= 0.0:
		for bomb_node in get_tree().get_nodes_in_group("bombs"):
			if is_instance_valid(bomb_node) and bomb_node is Node3D:
				var hit_dist := 1.8 * current_scale_multiplier
				if global_position.distance_to(bomb_node.global_position) <= hit_dist:
					print("💥🛸 UFO najechało na bombę!")
					_bomb_hit_cooldown = 0.8
					if bomb_node.has_method("detonate"):
						bomb_node.call("detonate")
					on_hit_bomb()
					return
	
	# Automatyczne odnalezienie gracza, jeśli jeszcze go nie przypisano
	if _target == null or not is_instance_valid(_target):
		_find_target_player()

	if _target != null and is_instance_valid(_target):
		var target_pos := _target.global_position
		var to_target := (target_pos - global_position)
		to_target.y = 0.0 # Pościg na płaszczyźnie XZ
		
		var dist := to_target.length()
		var current_attack_dist := attack_distance * current_scale_multiplier
		
		# Sprawdzenie bezpośredniego zasięgu ataku na gracza
		if dist <= current_attack_dist and _hit_cooldown <= 0.0:
			_trigger_hit(_target)
			
		# Obsługa ostrzału laserowego w stronę gracza
		if can_shoot:
			_shoot_timer += delta
			if _shoot_timer >= shoot_interval:
				_shoot_timer = 0.0
				_shoot_laser_at_player()
			
		if dist > 0.1:
			var desired_dir := to_target / dist
			var desired_velocity := desired_dir * (base_speed * _speed_multiplier)
			_current_velocity = _current_velocity.move_toward(desired_velocity, chase_acceleration * delta)
			
			# Obracanie spodka w stronę gracza z lekkim przechyłem (banking)
			if visuals:
				var target_yaw := atan2(desired_dir.x, desired_dir.z)
				visuals.rotation.y = lerp_angle(visuals.rotation.y, target_yaw, 8.0 * delta)
				visuals.rotation.z = lerp_angle(visuals.rotation.z, -desired_dir.x * deg_to_rad(12.0), 6.0 * delta)
	else:
		_current_velocity = _current_velocity.move_toward(Vector3.ZERO, chase_acceleration * delta)
		if visuals:
			visuals.rotate_y(0.8 * delta)
			
	global_position += _current_velocity * delta
	global_position.y = _base_y + hover_offset
	
	# Pulsowanie światła napędu
	if thruster_light:
		thruster_light.light_energy = 1.8 + sin(_time * 6.0) * 0.8


## Wystrzeliwuje plazmowy pocisk laserowy w stronę gracza
func _shoot_laser_at_player() -> void:
	if _target == null or not is_instance_valid(_target) or LASER_SCENE == null:
		return
		
	var spawn_pos := Vector3(global_position.x, _base_y + 0.1, global_position.z)
	var target_aim := _target.global_position + Vector3(0, 0.45, 0)
	var base_dir := (target_aim - spawn_pos).normalized()
	
	# Lekki kąt rozrzutu (+/- 6 stopni) dla ciekawszego unikania
	var spread_angle := randf_range(-0.1, 0.1)
	var shoot_dir := base_dir.rotated(Vector3.UP, spread_angle)
	
	var laser = LASER_SCENE.instantiate()
	var parent_node := get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	parent_node.add_child(laser)
	
	if laser.has_method("initialize"):
		laser.call("initialize", spawn_pos, shoot_dir)
	print("🛸🔫 UFO wystrzeliło laser plazmowy w gracza!")
	
	# Błysk kokpitu spodka przy wystrzale
	if thruster_light:
		var flash_tween := create_tween()
		flash_tween.tween_property(thruster_light, "light_energy", 6.0, 0.08)
		flash_tween.tween_property(thruster_light, "light_energy", 1.8, 0.18)


## Automatycznie wyszukuje gracza w drzewie węzłów
func _find_target_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node3D:
		_target = players[0]
		return
	var scene_root := get_tree().current_scene
	if scene_root:
		var p := scene_root.get_node_or_null("PlayerInstance")
		if p is Node3D:
			_target = p
			return
		p = scene_root.get_node_or_null("Player")
		if p is Node3D:
			_target = p


## Włącza pościg za celem (graczem)
func start_chasing(target_node: Node3D = null) -> void:
	if target_node != null:
		_target = target_node
	elif _target == null:
		_find_target_player()


## Zatrzymuje pościg
func stop_chasing() -> void:
	_target = null


## Zwiększa prędkość poruszania się UFO
func apply_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = multiplier


## Zatrzymuje UFO (np. na ekranie końca gry)
func freeze() -> void:
	_is_frozen = true


## Wznawia ruch UFO
func unfreeze() -> void:
	_is_frozen = false


# ==============================================================================
# MODYFIKACJE SKALI I PRĘDKOŚCI (VIBE CODING)
# ==============================================================================

## Reakcja na najechanie na bombę: zmniejsza się o 15% i przyspiesza o 15%!
func on_hit_bomb() -> void:
	# 1. Zmniejszenie skali o 15%
	shrink_by_percent(0.15)
	
	# 2. Przyspieszenie o 15%
	base_speed *= 1.15
	chase_acceleration *= 1.15
	print("🛸⚡ UFO PRZYSPIESZYŁO O 15%! Nowa prędkość bazowa: %.2f m/s" % base_speed)


## Powiększa UFO o 15% po pokonaniu gracza
func grow_by_percent(percent: float = 0.15) -> void:
	current_scale_multiplier *= (1.0 + percent)
	print("🛸📈 UFO UROSŁO O %d%%! Nowa skala: x%.2f" % [int(percent * 100), current_scale_multiplier])
	size_changed.emit(current_scale_multiplier)
	_apply_scale_effects(true)


## Zmniejsza UFO o 15% po najechaniu na bombę
func shrink_by_percent(percent: float = 0.15) -> void:
	current_scale_multiplier *= (1.0 - percent)
	print("🛸📉 UFO SKURCZYŁO SIĘ O %d%%! Nowa skala: x%.2f" % [int(percent * 100), current_scale_multiplier])
	size_changed.emit(current_scale_multiplier)
	
	# Jeśli UFO skurczy się poniżej 35% rozmiaru bazowego, następuje ostateczna eksplozja!
	if current_scale_multiplier <= 0.35:
		print("💥🛸 UFO było zbyt małe i całkowicie eksplodowało!")
		explode()
		return
		
	_apply_scale_effects(false)


## Animuje płynną zmianę skali i aktualizuje zasięg kolizji
func _apply_scale_effects(is_growing: bool) -> void:
	var target_scale := Vector3.ONE * current_scale_multiplier
	
	# Aktualizacja promienia kolizji
	if collision_shape and collision_shape.shape is CylinderShape3D:
		collision_shape.shape.radius = 1.4 * current_scale_multiplier
		collision_shape.shape.height = 0.8 * current_scale_multiplier
		
	if visuals:
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if is_growing:
			# Triumfalny rozrost (Juice pop)
			tween.tween_property(visuals, "scale", target_scale * 1.25, 0.18)
			tween.tween_property(visuals, "scale", target_scale, 0.16)
			if thruster_light:
				var light_tween := create_tween()
				light_tween.tween_property(thruster_light, "light_color", Color(3.5, 0.2, 0.5), 0.12)
				light_tween.tween_property(thruster_light, "light_color", Color(0.2, 1.8, 3.2), 0.28)
		else:
			# Zgniecenie i skurczenie po trafieniu
			tween.tween_property(visuals, "scale", target_scale * 0.75, 0.12)
			tween.tween_property(visuals, "scale", target_scale, 0.18)
			if thruster_light:
				var light_tween := create_tween()
				light_tween.tween_property(thruster_light, "light_color", Color(3.5, 1.8, 0.2), 0.1)
				light_tween.tween_property(thruster_light, "light_color", Color(0.2, 1.8, 3.2), 0.25)


## Spektakularny wybuch UFO
func explode() -> void:
	if is_exploding:
		return
		
	is_exploding = true
	_is_frozen = true
	_current_velocity = Vector3.ZERO
	exploded.emit()
	print("💥🛸 BUM! UFO EKSPLODUJE!")
	
	if visuals:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(visuals, "scale", Vector3(2.5, 2.5, 2.5), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(visuals, "rotation:y", visuals.rotation.y + PI * 4.0, 0.35)
		tween.tween_property(visuals, "rotation:x", deg_to_rad(90.0), 0.3)
		if thruster_light:
			tween.tween_property(thruster_light, "light_energy", 12.0, 0.15)
			
		await tween.finished
		visuals.visible = false
		
	# Po 4 sekundach odradza się nowe UFO ze startową skalą 1.0 i bazową prędkością
	await get_tree().create_timer(4.0).timeout
	_respawn_ufo()


## Odradza nowe UFO w bezpiecznej odległości od gracza
func _respawn_ufo() -> void:
	current_scale_multiplier = 1.0
	base_speed = _initial_base_speed
	chase_acceleration = _initial_chase_accel
	
	var angle := randf() * TAU
	global_position = Vector3(cos(angle) * 12.0, _base_y, sin(angle) * 12.0)
	_current_velocity = Vector3.ZERO
	
	if collision_shape and collision_shape.shape is CylinderShape3D:
		collision_shape.shape.radius = 1.4
		collision_shape.shape.height = 0.8
		
	if visuals:
		visuals.rotation = Vector3.ZERO
		visuals.scale = Vector3.ZERO
		visuals.visible = true
		var tween := create_tween()
		tween.tween_property(visuals, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	is_exploding = false
	_is_frozen = false
	print("🛸 Nowe UFO przybyło na pole bitwy!")


func _on_body_entered(body: Node3D) -> void:
	if _is_frozen or is_exploding or _hit_cooldown > 0.0:
		return
	if body.is_in_group("player") or body.name.begins_with("Player") or body.name == "PlayerInstance":
		_trigger_hit(body)


func _on_area_entered(area: Area3D) -> void:
	if is_exploding or _is_frozen or _bomb_hit_cooldown > 0.0:
		return
	# Zderzenie z bombą: detonacja, zmniejszenie o 15% i przyspieszenie o 15%!
	if area.is_in_group("bombs") or area.has_method("detonate") or area.name.to_lower().contains("bomb"):
		print("💥🛸 UFO wbiło się w bombę!")
		_bomb_hit_cooldown = 0.8
		if area.has_method("detonate"):
			area.call("detonate")
		on_hit_bomb()


func _trigger_hit(player_node: Node3D) -> void:
	if _hit_cooldown > 0.0 or is_exploding:
		return
	if player_node.has_method("is_invincible") and player_node.call("is_invincible"):
		return
		
	_hit_cooldown = 1.5
	hit_player.emit()
	print("💥 UFO trafiło gracza!")
	
	# POKONANIE GRACZA -> POWIĘKSZENIE UFO O 15%!
	grow_by_percent(0.15)
	
	if player_node.has_method("explode"):
		player_node.call("explode")
	elif player_node.has_signal("exploded"):
		player_node.emit_signal("exploded")
