class_name EnemyLaser3D
extends Area3D

## EnemyLaser3D - Pocisk plazmowy wystrzeliwany przez UFO w stronę gracza w pełnym 3D

signal hit_player

@export var speed: float = 9.5 ## Prędkość lotu lasera
@export var lifetime: float = 3.5 ## Czas życia pocisku

@onready var visuals: Node3D = $Visuals
@onready var light: OmniLight3D = $OmniLight3D

var direction := Vector3.FORWARD
var _time_alive: float = 0.0

func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)


func initialize(start_pos: Vector3, target_dir: Vector3) -> void:
	global_position = start_pos
	direction = target_dir.normalized()
	# Obrócenie pocisku wzdłuż wektora lotu
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_time_alive += delta
	
	if _time_alive >= lifetime:
		queue_free()
		return
		
	# Zabezpieczenie przed opuszczeniem areny
	var flat_pos := Vector2(global_position.x, global_position.z)
	if flat_pos.length() > 20.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player") or body.name == "PlayerInstance":
		# Jeśli gracz ma aktywną tarczę, laser zostaje zablokowany!
		if body.has_method("is_shield_active") and body.call("is_shield_active"):
			if body.has_method("block_projectile"):
				body.call("block_projectile")
			queue_free()
			return
			
		print("💥 Laser UFO trafił gracza!")
		hit_player.emit()
		if body.has_method("explode"):
			body.call("explode")
		elif body.has_signal("exploded"):
			body.emit_signal("exploded")
		queue_free()
