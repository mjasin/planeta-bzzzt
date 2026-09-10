class_name Star
extends Area2D

## Star - Skrypt neonowej zielonej gwiazdki z animacją unoszenia i znikaniem przez Tween.

signal collected(points: int)

# --- ZMIENNE EKSPORTOWANE ---
@export var points_value: int = 1
@export var rotation_speed: float = 2.0
@export var bobbing_speed: float = 4.0
@export var bobbing_amount: float = 8.0

# --- REFERENCJE ---
@onready var sprite: Sprite2D = $Sprite2D

# --- ZMIENNE PRYWATNE ---
var _start_position: Vector2
var _anim_time: float = 0.0
var _is_collected: bool = false

func _ready() -> void:
	add_to_group("stars")
	_start_position = position
	body_entered.connect(_on_body_entered)
	_setup_neon_green_glow()


## Ustawia nową pozycję gwiazdki oraz aktualizuje bazę do falowania Y
func set_star_position(new_pos: Vector2) -> void:
	position = new_pos
	_start_position = new_pos


func _process(delta: float) -> void:
	if _is_collected:
		return
		
	_anim_time += delta * bobbing_speed
	
	# Obrót i falowanie góra-dół
	rotation += rotation_speed * delta
	position.y = _start_position.y + sin(_anim_time) * bobbing_amount


## Ustawia jaskrawy neonowo-zielony odcień z poświatą HDR
func _setup_neon_green_glow() -> void:
	if sprite:
		sprite.modulate = Color(1.1, 1.4, 1.1, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
		
	if body.is_in_group("player") or body.name == "Player":
		_collect(body)


func _collect(player_node: Node2D) -> void:
	_is_collected = true
	print("⭐ Neonowa Gwiazdka zebrana! Dodano punktów: ", points_value)
	
	collected.emit(points_value)
	
	if player_node.has_method("trigger_pop_effect"):
		player_node.trigger_pop_effect()
	
	# Wybuch neonowo-zielonych cząsteczek
	_spawn_neon_green_sparks()
	
	# Wyłączamy kolizję
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Tween szybkiego zmniejszania do zera przed usunięciem (queue_free)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	
	await tween.finished
	queue_free()


## Tworzy wybuch jaskrawych, neonowo-zielonych iskier
func _spawn_neon_green_sparks() -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = 35
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 40)
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 240.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 9.0
	
	# Jaskrawy zielony odcień HDR
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.4, 3.5, 0.8, 1.0))
	gradient.set_color(1, Color(0.1, 1.0, 0.3, 0.0))
	particles.color_ramp = gradient
	
	get_parent().add_child(particles)
	particles.emitting = true
