class_name Portal3D
extends Area3D

## Portal3D - Świecący portal teleportacyjny w pełnym 3D

signal player_teleported

@export var target_position: Vector3 = Vector3(-6.0, 0.5, -5.0)
@export var rotation_speed: float = 3.0

@onready var vortex: MeshInstance3D = $Visuals/Vortex

var _cooldown: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if vortex:
		vortex.rotate_z(rotation_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0:
		return
	if body.is_in_group("player") or body.name.begins_with("Player"):
		_teleport(body)


func _teleport(body: Node3D) -> void:
	_cooldown = 2.0
	player_teleported.emit()
	body.global_position = target_position
