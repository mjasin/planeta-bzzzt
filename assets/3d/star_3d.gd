class_name Star3D
extends Area3D

## Star3D - Zbieralna świecąca gwiazdka 3D z animacją obrotu, unoszenia się i efektem zebrania

signal collected(points: int)

@export var points: int = 1
@export var rotation_speed: float = 2.5
@export var bob_speed: float = 3.5
@export var bob_height: float = 0.2

@onready var visuals: Node3D = $Visuals
@onready var light: OmniLight3D = $OmniLight3D

var _base_y: float = 0.0
var _time: float = 0.0
var _is_collected: bool = false

func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU # Losowa faza unoszenia dla każdej gwiazdki
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _is_collected:
		return
		
	_time += delta
	if visuals:
		visuals.rotate_y(rotation_speed * delta)
		position.y = _base_y + sin(_time * bob_speed) * bob_height

	# Zabezpieczenie odległościowe - sprawdzamy gracza po grupie lub po scenie
	var player_node: Node3D = null
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node3D:
		player_node = players[0]
	elif get_tree().current_scene:
		player_node = get_tree().current_scene.get_node_or_null("PlayerInstance")
		
	if player_node != null and is_instance_valid(player_node):
		var flat_dist := Vector2(global_position.x - player_node.global_position.x, global_position.z - player_node.global_position.z).length()
		var y_diff := absf(global_position.y - player_node.global_position.y)
		# Szeroki promień zebrania (2.2m na płaszczyźnie, do 2.5m w pionie)
		if flat_dist <= 2.2 and y_diff <= 2.5:
			_collect()
			return


func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return
	if body.is_in_group("player") or body.name.to_lower().contains("player"):
		_collect()


func _collect() -> void:
	_is_collected = true
	collected.emit(points)
	
	# Soczysty efekt zebrania (Juice pop)
	set_deferred("monitoring", false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visuals, "scale", Vector3(1.8, 1.8, 1.8), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "position:y", visuals.position.y + 0.8, 0.2)
	if light:
		tween.tween_property(light, "light_energy", 5.0, 0.1)
		
	await tween.finished
	var fade_tween := create_tween()
	fade_tween.tween_property(visuals, "scale", Vector3.ZERO, 0.15)
	await fade_tween.finished
	queue_free()
