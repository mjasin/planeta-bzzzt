class_name Player
extends CharacterBody2D

## Player - Skrypt gracza z logiką wybuchu, odrodzenia, miecza laserowego oraz tarczy odbijającej pociski UFO.

# --- SYGNAŁY ---
signal exploded ## Wysyłany, gdy gracz wpadnie w meteor/UFO i wybuchnie
signal sword_swung ## Wysyłany przy zamachu mieczem
signal shield_activated ## Wysyłany przy włączeniu tarczy
signal shield_deflected ## Wysyłany po skutecznym odbiciu pocisku tarczą

# --- ZMIENNE EKSPORTOWANE ---
@export var speed: float = 300.0 ## Prędkość gracza w pikselach na sekundę
@export var rotation_tilt_amount: float = 0.001 ## Przechył przy ruchu

@export_group("Miecz Świetlny")
@export var sword_swing_duration: float = 0.22 ## Czas trwania pojedynczego cięcia mieczem
@export var sword_cooldown: float = 0.28 ## Minimalny odstęp między zamachami miecza
@export var sword_knockback_force: float = 240.0 ## Siła odrzucenia UFO po trafieniu mieczem

@export_group("Tarcza Odbijająca Pociski")
@export var shield_duration: float = 1.6 ## Czas działania tarczy po aktywacji (sekundy)
@export var shield_cooldown: float = 2.4 ## Czas odnowienia tarczy
@export var shield_reflect_speed_bonus: float = 1.5 ## Przyspieszenie odbitego pocisku

# --- REFERENCJE DO WĘZŁÓW ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Miecz
@onready var sword_pivot: Node2D = get_node_or_null("SwordPivot")
@onready var sword_area: Area2D = get_node_or_null("SwordPivot/SwordArea")
@onready var sword_sprite: Sprite2D = get_node_or_null("SwordPivot/SwordArea/Sprite2D")
@onready var sword_collision: CollisionShape2D = get_node_or_null("SwordPivot/SwordArea/CollisionShape2D")

# Tarcza
@onready var shield_area: Area2D = get_node_or_null("ShieldArea")
@onready var shield_sprite: Sprite2D = get_node_or_null("ShieldArea/Sprite2D")
@onready var shield_collision: CollisionShape2D = get_node_or_null("ShieldArea/CollisionShape2D")

# --- ZMIENNE PRYWATNE ---
var _start_position: Vector2
var _base_speed: float = 300.0
var _base_scale: Vector2 = Vector2.ONE
var _anim_time: float = 0.0
var _trail_particles: CPUParticles2D
var _aura_particles: CPUParticles2D
var is_exploding: bool = false
var is_frozen: bool = false

# Stan miecza
var is_swinging_sword: bool = false
var _can_swing_sword: bool = true
var _facing_direction: Vector2 = Vector2.RIGHT

# Stan tarczy
var is_shield_active: bool = false
var _can_activate_shield: bool = true
var _shield_tween: Tween

func _ready() -> void:
	add_to_group("player")
	_start_position = global_position
	_base_speed = speed
	_base_scale = scale
	_setup_neon_glow()
	_setup_trail_particles()
	_setup_aura_particles()
	_setup_sword()
	_setup_shield()


func _process(delta: float) -> void:
	if is_exploding or is_frozen:
		return
	_anim_time += delta * 3.0
	_apply_breathing_effect()
	_apply_tilt_effect(delta)
	
	# Delikatne lewitowanie miecza w stanie spoczynku
	if not is_swinging_sword and sword_area:
		var float_offset: float = sin(_anim_time * 2.0) * 3.0
		sword_area.position.y = float_offset
		
	# Rotacja i pulsowanie bariery tarczy, gdy jest aktywna
	if is_shield_active and shield_area:
		shield_area.rotation += delta * 2.5


func _physics_process(_delta: float) -> void:
	if is_exploding or is_frozen:
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
	
	if direction.length_squared() > 0.05:
		_facing_direction = direction.normalized()
		if not is_swinging_sword and sword_pivot:
			sword_pivot.rotation = _facing_direction.angle()
	
	if _trail_particles:
		_trail_particles.emitting = velocity.length_squared() > 10.0


func _unhandled_input(event: InputEvent) -> void:
	if is_exploding or is_frozen:
		return
		
	# 1. Atak mieczem pod Spacją, klawiszem X, F lub LPM
	var attack_triggered: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_X or event.keycode == KEY_F:
			attack_triggered = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		attack_triggered = true
		
	if attack_triggered and _can_swing_sword and not is_swinging_sword:
		if event is InputEventMouseButton:
			var mouse_pos := get_global_mouse_position()
			_facing_direction = (mouse_pos - global_position).normalized()
		swing_sword()

	# 2. Włączenie tarczy pod PPM (Prawym Przyciskiem Myszy), Shiftem lub klawiszem C
	var shield_triggered: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		shield_triggered = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SHIFT or event.keycode == KEY_C or event.keycode == KEY_Z:
			shield_triggered = true
			
	if shield_triggered and _can_activate_shield and not is_shield_active:
		activate_shield()


# ==============================================================================
# MECHANIKA TARCZY ODBIJAJĄCEJ POCISKI (DEFLECTING SHIELD)
# ==============================================================================

func _setup_shield() -> void:
	if shield_area:
		shield_area.visible = false
		shield_area.set_deferred("monitoring", false)
		shield_area.set_deferred("monitorable", false)
		if not shield_area.area_entered.is_connected(_on_shield_area_entered):
			shield_area.area_entered.connect(_on_shield_area_entered)
		if not shield_area.body_entered.is_connected(_on_shield_body_entered):
			shield_area.body_entered.connect(_on_shield_body_entered)


## Włącza pole siłowe tarczy
func activate_shield() -> void:
	if is_shield_active or not _can_activate_shield or shield_area == null:
		return
		
	is_shield_active = true
	_can_activate_shield = false
	shield_activated.emit()
	print("🛡️ TARCZA AKTYWOWANA! Pole siłowe odbija pociski UFO!")
	
	shield_area.visible = true
	shield_area.scale = Vector2.ZERO
	shield_area.set_deferred("monitoring", true)
	shield_area.set_deferred("monitorable", true)
	
	if _shield_tween:
		_shield_tween.kill()
		
	# Soczyste rozszerzenie bariery (Elastic / Back)
	_shield_tween = create_tween().set_parallel(true)
	_shield_tween.tween_property(shield_area, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if shield_sprite:
		shield_sprite.modulate = Color(2.0, 3.5, 4.0, 1.0)
		_shield_tween.tween_property(shield_sprite, "modulate", Color(1.0, 2.5, 3.5, 0.85), 0.3)
	
	# Błysk aury wokół bohatera
	_spawn_shield_activate_burst()
	
	# Czas trwania tarczy
	await get_tree().create_timer(shield_duration).timeout
	deactivate_shield()
	
	# Czas odnowienia (cooldown)
	await get_tree().create_timer(shield_cooldown - shield_duration).timeout
	_can_activate_shield = true
	print("⚡ Tarcza naładowana i gotowa do użycia!")


## Wyłącza pole siłowe tarczy
func deactivate_shield() -> void:
	if not is_shield_active or shield_area == null:
		return
		
	is_shield_active = false
	shield_area.set_deferred("monitoring", false)
	shield_area.set_deferred("monitorable", false)
	
	# Zwinięcie tarczy
	var fade_tween := create_tween()
	fade_tween.tween_property(shield_area, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await fade_tween.finished
	if is_instance_valid(shield_area):
		shield_area.visible = false


## Odbicie wrogich pocisków przez tarczę
func _on_shield_area_entered(area: Area2D) -> void:
	if not is_shield_active:
		return
		
	# Wykrywamy wrogi pocisk laserowy
	if area.is_in_group("enemy_projectiles") or area is EnemyLaser:
		_deflect_laser_projectile(area)
	elif area.is_in_group("enemies") or area.is_in_group("ufos") or area is UFO:
		# Jeśli UFO zderzy się z aktywną tarczą – zostaje brutalnie odrzucone
		_defend_against_ufo(area)


func _on_shield_body_entered(body: Node2D) -> void:
	if not is_shield_active:
		return
	if body.is_in_group("enemies") or body.is_in_group("ufos"):
		_defend_against_ufo(body)


## Odbija pocisk laserowy prosto w stronę źródła lub Złego UFO
func _deflect_laser_projectile(laser: Area2D) -> void:
	print("🛡️⚡ TARCZA ODBIŁA POCISK UFO!")
	shield_deflected.emit()
	
	# Szukamy wrogiego UFO, aby wycelować odbity pocisk prosto w kosmitów!
	var ufo_nodes := get_tree().get_nodes_in_group("enemies")
	var target_pos := Vector2.ZERO
	if ufo_nodes.size() > 0 and is_instance_valid(ufo_nodes[0]):
		target_pos = ufo_nodes[0].global_position
	else:
		# Jeśli nie znaleziono UFO, odbij w stronę przeciwną do lotu pocisku
		target_pos = laser.global_position - (laser.global_position - global_position).normalized() * 300.0
		
	var reflect_dir: Vector2 = (target_pos - laser.global_position).normalized()
	if reflect_dir == Vector2.ZERO:
		reflect_dir = -_facing_direction
		
	# Wywołujemy metodę deflect na pocisku (laser_enemy.gd)
	if laser.has_method("deflect"):
		laser.call("deflect", reflect_dir, shield_reflect_speed_bonus)
	else:
		# Fallback jeśli pocisk nie ma metody deflect
		laser.queue_free()
		
	# Efekt rozbłysku tarczy przy odbiciu
	_spawn_deflect_impact_burst(laser.global_position)
	if shield_sprite:
		var flash_tween := create_tween()
		flash_tween.tween_property(shield_sprite, "modulate", Color(4.0, 4.0, 4.0, 1.0), 0.06)
		flash_tween.tween_property(shield_sprite, "modulate", Color(1.0, 2.5, 3.5, 0.85), 0.14)


## Rozbłysk przy włączeniu tarczy
func _spawn_shield_activate_burst() -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = 25
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 220.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.3, 3.0, 4.0, 0.9)
	get_parent().add_child(particles)
	particles.emitting = true


## Efekt eksplozji energii przy odbiciu pocisku
func _spawn_deflect_impact_burst(impact_pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = impact_pos
	particles.amount = 30
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.explosiveness = 0.98
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 140.0
	particles.initial_velocity_max = 280.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = Color(3.5, 3.5, 0.5, 1.0) # Złoto-błękitne iskry odbicia
	get_parent().add_child(particles)
	particles.emitting = true


# ==============================================================================
# MECHANIKA MIECZA ŚWIETLNEGO (SWORD DEFENSE)
# ==============================================================================

func _setup_sword() -> void:
	if sword_area:
		sword_area.set_deferred("monitoring", false)
		sword_area.set_deferred("monitorable", false)
		if not sword_area.area_entered.is_connected(_on_sword_hit_area):
			sword_area.area_entered.connect(_on_sword_hit_area)
		if not sword_area.body_entered.is_connected(_on_sword_hit_body):
			sword_area.body_entered.connect(_on_sword_hit_body)
			
	if sword_sprite:
		sword_sprite.modulate = Color(1.2, 2.0, 3.5, 0.85)


## Wyprowadza potężne, soczyste cięcie mieczem
func swing_sword() -> void:
	if is_swinging_sword or not _can_swing_sword or sword_pivot == null or sword_area == null:
		return
		
	is_swinging_sword = true
	_can_swing_sword = false
	sword_swung.emit()
	
	# Włączamy detekcję kolizji ostrza
	sword_area.set_deferred("monitoring", true)
	sword_area.set_deferred("monitorable", true)
	
	# Błysk miecza na biało-błękitny neon
	if sword_sprite:
		sword_sprite.modulate = Color(3.5, 3.5, 4.0, 1.0)
	
	# Kąt bazowy skierowany tam, gdzie patrzy gracz
	var base_angle := _facing_direction.angle()
	var start_angle := base_angle - deg_to_rad(100.0)
	var end_angle := base_angle + deg_to_rad(100.0)
	
	sword_pivot.rotation = start_angle
	
	# Soczysty zamach mieczem (Tween)
	var swing_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(sword_pivot, "rotation", end_angle, sword_swing_duration)
	
	# Efekt fali uderzeniowej / cięcia cząsteczkowego
	_spawn_sword_slash_particles(_facing_direction)
	
	await swing_tween.finished
	
	# Wyłączamy zadawanie obrażeń po zakończeniu zamachu
	sword_area.set_deferred("monitoring", false)
	sword_area.set_deferred("monitorable", false)
	is_swinging_sword = false
	
	# Płynny powrót miecza do pozycji neutralnej
	var return_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(sword_pivot, "rotation", base_angle, 0.1)
	if sword_sprite:
		return_tween.parallel().tween_property(sword_sprite, "modulate", Color(1.2, 2.0, 3.5, 0.85), 0.15)
	
	# Cooldown przed kolejnym atakiem
	await get_tree().create_timer(sword_cooldown - sword_swing_duration).timeout
	_can_swing_sword = true


## Kolizja miecza z obiektami Area2D (np. Laser UFO lub UFO jeśli jest Area2D)
func _on_sword_hit_area(area: Area2D) -> void:
	if not is_swinging_sword:
		return
		
	# 1. Przecięcie / zniszczenie pocisku laserowego wroga
	if area.is_in_group("enemy_projectiles") or area is EnemyLaser:
		print("⚔️ CIĘCIE MIECZEM! Pocisk laserowy UFO został rozcięty na kawałki!")
		_spawn_sword_spark_burst(area.global_position, Color(0.2, 3.5, 3.0, 1.0))
		area.queue_free()
		return
		
	# 2. Uderzenie mieczem w UFO
	if area.is_in_group("enemies") or area.is_in_group("ufos") or area is UFO:
		_defend_against_ufo(area)


## Kolizja miecza z ciałami fizycznymi
func _on_sword_hit_body(body: Node2D) -> void:
	if not is_swinging_sword:
		return
		
	if body.is_in_group("enemies") or body.is_in_group("ufos"):
		_defend_against_ufo(body)


## Odrzuca UFO, oszałamia je (stun) i generuje efektowne iskry
func _defend_against_ufo(enemy_node: Node2D) -> void:
	print("⚔️ TRAFIENIE UFO MIECZEM/TARCZĄ! Kosmici zostali odrzuceni i oszołomieni!")
	
	# Efektowne iskry uderzenia miecza
	var hit_pos: Vector2 = (global_position + enemy_node.global_position) / 2.0
	_spawn_sword_spark_burst(hit_pos, Color(3.5, 3.0, 0.3, 1.0))
	
	# Wektor odepchnięcia UFO od gracza
	var knockback_dir := (enemy_node.global_position - global_position).normalized()
	if knockback_dir == Vector2.ZERO:
		knockback_dir = _facing_direction
		
	var target_pos := enemy_node.global_position + knockback_dir * sword_knockback_force
	
	# Odrzucenie wroga za pomocą Tweena
	var knock_tween := enemy_node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	knock_tween.tween_property(enemy_node, "global_position", target_pos, 0.25)
	
	# Błysk i ogłuszenie UFO
	if enemy_node.has_method("freeze") and enemy_node.has_method("unfreeze"):
		enemy_node.call("freeze")
		var sprite_node = enemy_node.get_node_or_null("Sprite2D")
		if sprite_node:
			sprite_node.modulate = Color(3.5, 0.5, 3.5, 1.0)
		
		# UFO dochodzi do siebie po 1.2 sekundy
		await get_tree().create_timer(1.2).timeout
		if is_instance_valid(enemy_node):
			enemy_node.call("unfreeze")


## Cząsteczki rozbłysku cięcia miecza (Slash arc)
func _spawn_sword_slash_particles(dir: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = global_position + dir * 35.0
	particles.amount = 25
	particles.lifetime = 0.25
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = dir
	particles.spread = 60.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 240.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = Color(0.2, 3.0, 3.5, 0.9)
	
	get_parent().add_child(particles)
	particles.emitting = true


## Iskry przy trafieniu mieczem (kolorowe odłamki energii)
func _spawn_sword_spark_burst(spark_pos: Vector2, spark_color: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = spark_pos
	particles.amount = 35
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 0.98
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 260.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 9.0
	particles.color = spark_color
	
	get_parent().add_child(particles)
	particles.emitting = true


# ==============================================================================
# LOGIKA WYBUCHU I ODRODZENIA (BOOM!)
# ==============================================================================

## Wywołuje wybuch gracza, ukrywa postać i resetuje pozycję
func explode() -> void:
	# Jeśli aktywna jest tarcza, gracz jest niezniszczalny!
	if is_shield_active:
		print("🛡️ Tarcza ochroniła gracza przed wybuchem!")
		return
		
	if is_exploding:
		return
	is_exploding = true
	print("💥 BZZZT! BOOM! Złe UFO dopadło gracza!")
	
	exploded.emit()
	
	# Ukrywamy miecz i tarczę podczas wybuchu
	if sword_pivot:
		sword_pivot.visible = false
	if sword_area:
		sword_area.set_deferred("monitoring", false)
		sword_area.set_deferred("monitorable", false)
	if shield_area:
		shield_area.visible = false
		shield_area.set_deferred("monitoring", false)
		shield_area.set_deferred("monitorable", false)
	is_shield_active = false
	
	# Efekt cząsteczkowy eksplozji
	_spawn_explosion_particles()
	
	# Ukrywamy postać i wyłączamy kolizję oraz ruch
	sprite.visible = false
	if _trail_particles:
		_trail_particles.emitting = false
	if _aura_particles:
		_aura_particles.emitting = false
	collision_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	
	# Czekamy chwilę na odrodzenie (1 sekunda)
	await get_tree().create_timer(1.0).timeout
	
	# Odrodzenie gracza na pozycji startowej
	_respawn()


## Odradza gracza na pozycji początkowej
func _respawn() -> void:
	global_position = _start_position
	rotation = 0.0
	scale = _base_scale
	sprite.visible = true
	if sword_pivot:
		sword_pivot.visible = true
	if _aura_particles:
		_aura_particles.emitting = true
	collision_shape.set_deferred("disabled", false)
	_setup_neon_glow()
	is_exploding = false
	print("✨ Gracz odrodził się na startowej pozycji!")


## Generuje potężny snop neonowych cząsteczek eksplozji
func _spawn_explosion_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = 60
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 350.0
	particles.scale_amount_min = 6.0
	particles.scale_amount_max = 14.0
	
	var gradient := Gradient.new()
	gradient.set_color(0, Color(3.5, 0.3, 0.2, 1.0))
	gradient.set_color(0.5, Color(3.0, 1.5, 0.2, 0.9))
	gradient.set_color(1, Color(0.2, 1.5, 3.5, 0.0))
	particles.color_ramp = gradient
	
	get_parent().add_child(particles)
	particles.emitting = true


# ==============================================================================
# NEONOWE EFEKTY WIZUALNE
# ==============================================================================

func _setup_neon_glow() -> void:
	if sprite:
		sprite.modulate = Color(1.1, 1.3, 1.6, 1.0)


func _apply_breathing_effect() -> void:
	if sprite:
		var pulse: float = sin(_anim_time) * 0.05
		sprite.scale = Vector2(1.0 + pulse, 1.0 - pulse)


func _apply_tilt_effect(delta: float) -> void:
	var target_rotation: float = velocity.x * rotation_tilt_amount
	rotation = lerpf(rotation, target_rotation, delta * 12.0)


func _setup_trail_particles() -> void:
	_trail_particles = CPUParticles2D.new()
	_trail_particles.amount = 25
	_trail_particles.lifetime = 0.35
	_trail_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_trail_particles.emission_sphere_radius = 10.0
	_trail_particles.gravity = Vector2(0, 0)
	_trail_particles.scale_amount_min = 4.0
	_trail_particles.scale_amount_max = 8.0
	_trail_particles.color = Color(0.2, 2.0, 3.5, 0.7)
	_trail_particles.emitting = false
	add_child(_trail_particles)


func _setup_aura_particles() -> void:
	_aura_particles = CPUParticles2D.new()
	_aura_particles.amount = 30
	_aura_particles.lifetime = 1.2
	_aura_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_aura_particles.emission_sphere_radius = 28.0
	_aura_particles.gravity = Vector2(0, 0)
	_aura_particles.orbit_velocity_min = 0.5
	_aura_particles.orbit_velocity_max = 1.0
	_aura_particles.scale_amount_min = 2.0
	_aura_particles.scale_amount_max = 4.0
	_aura_particles.color = Color(0.3, 1.5, 3.0, 0.8)
	_aura_particles.emitting = true
	add_child(_aura_particles)


func trigger_pop_effect() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _base_scale * 1.25, 0.1)
	tween.tween_property(self, "scale", _base_scale, 0.18)


# ==============================================================================
# MODYFIKATORY NA ŻYWO (VIBE CODING)
# ==============================================================================

func apply_speed_boost(multiplier: float = 1.6, duration: float = 3.0) -> void:
	speed = _base_speed * multiplier
	trigger_pop_effect()
	set_flash_color(Color(2.5, 2.0, 0.3))
	
	await get_tree().create_timer(duration).timeout
	
	speed = _base_speed
	_setup_neon_glow()


func change_scale(new_scale: Vector2, duration: float = 0.0) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", new_scale, 0.3)
	
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		var return_tween := create_tween()
		return_tween.tween_property(self, "scale", _base_scale, 0.3)


func set_flash_color(color: Color) -> void:
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", color, 0.2)


## Zatrzymuje gracza (np. po wygraniu poziomu)
func freeze() -> void:
	is_frozen = true
	velocity = Vector2.ZERO
	if _trail_particles:
		_trail_particles.emitting = false


## Odblokowuje ruch gracza
func unfreeze() -> void:
	is_frozen = false
