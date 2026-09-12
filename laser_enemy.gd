class_name EnemyLaser
extends Area2D

## EnemyLaser - Pocisk plazmowy wystrzeliwany przez Złe UFO w kierunku gracza.

signal hit_target(target: Node2D)

# --- ZMIENNE EKSPORTOWANE ---
@export var speed: float = 225.0 ## Prędkość lotu lasera w pikselach na sekundę (zbalansowana pod ciągły ostrzał)
@export var lifetime: float = 4.0 ## Czas życia pocisku przed zniknięciem

# --- REFERENCJE DO WĘZŁÓW ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# --- ZMIENNE PRYWATNE ---
var direction: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0
var _trail_particles: CPUParticles2D

func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)
	_setup_trail()


func initialize(start_pos: Vector2, target_dir: Vector2) -> void:
	global_position = start_pos
	direction = target_dir.normalized()
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_time_alive += delta
	
	if _time_alive >= lifetime:
		_expire()


func _setup_trail() -> void:
	_trail_particles = CPUParticles2D.new()
	_trail_particles.name = "LaserTrail"
	_trail_particles.amount = 16
	_trail_particles.lifetime = 0.2
	_trail_particles.gravity = Vector2.ZERO
	_trail_particles.scale_amount_min = 2.0
	_trail_particles.scale_amount_max = 5.0
	_trail_particles.color = Color(3.5, 0.2, 1.2, 0.8) # Neon Magenta
	add_child(_trail_particles)
	_trail_particles.emitting = true


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		print("💥 BZZZT! Laser UFO trafił w gracza!")
		hit_target.emit(body)
		if body.has_method("explode"):
			body.call("explode")
		_spawn_impact_particles()
		queue_free()


func _expire() -> void:
	_spawn_impact_particles()
	queue_free()


## Efekt wybuchu iskier przy uderzeniu lasera
func _spawn_impact_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = 20
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 180.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	
	var gradient := Gradient.new()
	gradient.set_color(0, Color(3.5, 0.2, 0.8, 1.0))
	gradient.add_point(0.5, Color(3.5, 3.0, 0.2, 1.0))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.2, 1.5, 3.5, 0.0))
	particles.color_ramp = gradient
	
	get_parent().add_child(particles)
	particles.emitting = true
