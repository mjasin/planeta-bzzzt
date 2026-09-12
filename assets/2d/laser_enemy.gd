class_name EnemyLaser
extends Area2D

## EnemyLaser - Pocisk plazmowy wystrzeliwany przez Złe UFO w kierunku gracza.
## Może zostać przecięty mieczem lub odbity tarczą gracza prosto w UFO!

signal hit_target(target: Node2D)
signal deflected ## Wysyłany przy odbiciu tarczą

# --- ZMIENNE EKSPORTOWANE ---
@export var speed: float = 225.0 ## Prędkość lotu lasera w pikselach na sekundę
@export var lifetime: float = 4.0 ## Czas życia pocisku przed zniknięciem

# --- REFERENCJE DO WĘZŁÓW ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# --- ZMIENNE PRYWATNE ---
var direction: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0
var _trail_particles: CPUParticles2D
var is_deflected: bool = false ## Czy pocisk został odbity tarczą

func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
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
		return
		
	# Zabezpieczenie: pocisk eksploduje i znika natychmiast po opuszczeniu planszy
	var vp_size := get_viewport_rect().size
	if vp_size.x > 0 and vp_size.y > 0:
		if global_position.x < -20 or global_position.x > vp_size.x + 20 or global_position.y < -20 or global_position.y > vp_size.y + 20:
			_expire()
			return


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


## Odbicie pocisku przez tarczę gracza
func deflect(new_direction: Vector2, speed_bonus: float = 1.4) -> void:
	if is_deflected:
		return
	is_deflected = true
	remove_from_group("enemy_projectiles")
	add_to_group("deflected_projectiles")
	
	direction = new_direction.normalized()
	speed *= speed_bonus
	rotation = direction.angle()
	_time_alive = 0.0 # Odnawia czas życia pocisku po odbiciu
	
	# Zmiana barwy lasera na neonowy błękit/cyan (energia gracza)
	if sprite:
		sprite.modulate = Color(0.3, 3.5, 3.5, 1.0)
	if _trail_particles:
		_trail_particles.color = Color(0.2, 3.0, 3.5, 0.8)
		
	deflected.emit()
	print("⚡ POCISK ODBITY TARCZĄ! Leci z powrotem w kosmitów!")


func _on_body_entered(body: Node2D) -> void:
	# Gdy pocisk jest wrogi, rani gracza
	if not is_deflected:
		if body.is_in_group("player") or body.name == "Player":
			print("💥 BZZZT! Laser UFO trafił w gracza!")
			hit_target.emit(body)
			if body.has_method("explode"):
				body.call("explode")
			_spawn_impact_particles(Color(3.5, 0.2, 0.8, 1.0))
			queue_free()


func _on_area_entered(area: Area2D) -> void:
	# Gdy pocisk został odbity tarczą i trafia w UFO (Area2D)
	if is_deflected:
		if area.is_in_group("enemies") or area.is_in_group("ufos") or area is UFO:
			print("💥 BUM! Odbity pocisk trafił w UFO!")
			_spawn_impact_particles(Color(0.2, 3.5, 3.5, 1.0))
			if area.has_method("freeze") and area.has_method("unfreeze"):
				area.call("freeze")
				# Odrzucenie UFO od trafionego pocisku
				var tween := area.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_property(area, "global_position", area.global_position + direction * 180.0, 0.3)
				var sprite_node = area.get_node_or_null("Sprite2D")
				if sprite_node:
					sprite_node.modulate = Color(3.5, 3.5, 1.0, 1.0)
				await get_tree().create_timer(1.2).timeout
				if is_instance_valid(area):
					area.call("unfreeze")
			queue_free()


func _expire() -> void:
	_spawn_impact_particles(Color(3.5, 0.2, 0.8, 1.0))
	queue_free()


## Efekt wybuchu iskier przy uderzeniu lasera
func _spawn_impact_particles(spark_color: Color) -> void:
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
	gradient.set_color(0, spark_color)
	gradient.add_point(0.5, Color(3.5, 3.0, 0.2, 1.0))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.2, 1.5, 3.5, 0.0))
	particles.color_ramp = gradient
	
	get_parent().add_child(particles)
	particles.emitting = true
