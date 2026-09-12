class_name Player
extends CharacterBody2D

## Player - Skrypt gracza z logiką wybuchu i odrodzenia po trafieniu w meteor.

# --- SYGNAŁY ---
signal exploded ## Wysyłany, gdy gracz wpadnie w meteor i wybuchnie

# --- ZMIENNE EKSPORTOWANE ---
@export var speed: float = 300.0 ## Prędkość gracza w pikselach na sekundę
@export var rotation_tilt_amount: float = 0.001 ## Przechył przy ruchu

# --- REFERENCJE DO WĘZŁÓW ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# --- ZMIENNE PRYWATNE ---
var _start_position: Vector2
var _base_speed: float = 300.0
var _base_scale: Vector2 = Vector2.ONE
var _anim_time: float = 0.0
var _trail_particles: CPUParticles2D
var _aura_particles: CPUParticles2D
var is_exploding: bool = false
var is_frozen: bool = false

func _ready() -> void:
	add_to_group("player")
	_start_position = global_position
	_base_speed = speed
	_base_scale = scale
	_setup_neon_glow()
	_setup_trail_particles()
	_setup_aura_particles()


func _process(delta: float) -> void:
	if is_exploding or is_frozen:
		return
	_anim_time += delta * 3.0
	_apply_breathing_effect()
	_apply_tilt_effect(delta)


func _physics_process(_delta: float) -> void:
	if is_exploding or is_frozen:
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
	
	if _trail_particles:
		_trail_particles.emitting = velocity.length_squared() > 10.0


# ==============================================================================
# LOGIKA WYBUCHU I ODRODZENIA (BOOM!)
# ==============================================================================

## Wywołuje wybuch gracza, ukrywa postać i resetuje pozycję
func explode() -> void:
	if is_exploding:
		return
	is_exploding = true
	print("💥 BZZZT! BOOM! Złe UFO dopadło gracza!")
	
	exploded.emit()
	
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
	
	# Ognisto-neonowe barwy wybuchu (Czerwony / Pomarańczowy / Niebieski HDR)
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
