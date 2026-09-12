class_name Bomb3D
extends Area3D

## Bomb3D - Wybuchająca cyber-bomba z tykającym zapalnikiem, rozbłyskiem i niszczeniem UFO

signal exploded(bomb_position: Vector3)

@export_group("Właściwości Bomby")
@export var fuse_time: float = 1.8 ## Czas do wybuchu w sekundach
@export var blast_radius: float = 4.2 ## Promień fali uderzeniowej
@export var auto_trigger_proximity: float = 2.4 ## Odległość aktywująca tykanie miny

@onready var visuals: Node3D = $Visuals
@onready var bomb_light: OmniLight3D = $BombLight
@onready var explosion_mesh: MeshInstance3D = $ExplosionMesh
@onready var blast_area: Area3D = $BlastArea
@onready var blast_collision: CollisionShape3D = $BlastArea/CollisionShape3D

var is_player_bomb: bool = false
var _player_immunity_timer: float = 1.0 ## Gracz ma 1s na oddalenie się bez natychmiastowego wybuchu
var _time_left: float = 0.0
var _is_ticking: bool = false
var _has_exploded: bool = false
var _blink_timer: float = 0.0
var _initial_scale := Vector3.ONE

func _ready() -> void:
	_time_left = fuse_time
	_initial_scale = visuals.scale
	if explosion_mesh:
		explosion_mesh.visible = false
		explosion_mesh.scale = Vector3.ZERO
	if blast_collision and blast_collision.shape is SphereShape3D:
		blast_collision.shape.radius = blast_radius
		
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if _has_exploded:
		return
		
	if _player_immunity_timer > 0.0:
		_player_immunity_timer -= delta
		
	# Jeśli mina leży na mapie i nie tyka, sprawdzaj zbliżenie
	if not _is_ticking and auto_trigger_proximity > 0.0:
		_check_proximity()
		
	if _is_ticking:
		_time_left -= delta
		_update_ticking_animation(delta)
		
		if _time_left <= 0.0:
			detonate()


## Uruchamia odliczanie zapalnika
func start_fuse(duration: float = -1.0) -> void:
	if duration > 0.0:
		_time_left = duration
	_is_ticking = true


## Sprawdza czy ktoś zbliżył się do miny
func _check_proximity() -> void:
	# Sprawdzanie gracza
	if _player_immunity_timer <= 0.0:
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p is Node3D:
				if global_position.distance_to(p.global_position) <= auto_trigger_proximity:
					start_fuse()
					return
					
	# Sprawdzanie UFO - jeśli jest blisko, detonuj natychmiast!
	for enemy in get_tree().get_nodes_in_group("ufos"):
		if is_instance_valid(enemy) and enemy is Node3D:
			if global_position.distance_to(enemy.global_position) <= auto_trigger_proximity:
				detonate()
				return


## Animacja tykania – coraz szybsze miganie na czerwono i pulsowanie skali
func _update_ticking_animation(delta: float) -> void:
	var progress := 1.0 - (_time_left / maxf(fuse_time, 0.1))
	var blink_speed: float = float(lerp(3.0, 18.0, clampf(progress, 0.0, 1.0)))
	_blink_timer += delta * blink_speed
	
	var is_on := sin(_blink_timer * TAU) > 0.0
	if bomb_light:
		bomb_light.light_color = Color(3.5, 0.2, 0.2, 1.0) if is_on else Color(0.2, 0.0, 0.0, 1.0)
		bomb_light.light_energy = 3.5 if is_on else 0.5
		
	# Pulsowanie i puchnięcie bomby przed wybuchem (Juice!)
	var swell := 1.0 + sin(_blink_timer * TAU) * 0.18 * clampf(progress, 0.0, 1.0)
	visuals.scale = _initial_scale * swell


## Detonacja bomby
func detonate() -> void:
	if _has_exploded:
		return
	_has_exploded = true
	_is_ticking = false
	exploded.emit(global_position)
	print("💥 BUM! Bomba eksplodowała na pozycji: %s" % str(global_position))
	
	# Ukrycie obudowy bomby
	if visuals:
		visuals.visible = false
		
	# Błysk światła
	if bomb_light:
		bomb_light.light_color = Color(3.5, 1.8, 0.3, 1.0)
		bomb_light.light_energy = 8.0
		bomb_light.omni_range = blast_radius * 2.2
		
	# Efekt fali uderzeniowej (ekspandująca kula ognia)
	if explosion_mesh:
		explosion_mesh.visible = true
		explosion_mesh.scale = Vector3(0.2, 0.2, 0.2)
		var tween := create_tween().set_parallel(true)
		var target_scale := Vector3.ONE * blast_radius * 2.0
		tween.tween_property(explosion_mesh, "scale", target_scale, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if bomb_light:
			tween.tween_property(bomb_light, "light_energy", 0.0, 0.38)
			
	# Zadanie obrażeń i zniszczenie wrogów w promieniu wybuchu
	_apply_blast_damage()
	
	await get_tree().create_timer(0.4).timeout
	queue_free()


## Zadawanie obrażeń w promieniu wybuchu
func _apply_blast_damage() -> void:
	# 1. Gracz
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p is Node3D:
			var dist := global_position.distance_to(p.global_position)
			if dist <= blast_radius:
				if p.has_method("explode"):
					p.call("explode")
					
	# 2. UFO / Wrogowie (ZMNIEJSZENIE O 15% I PRZYSPIESZENIE O 15%!)
	for enemy in get_tree().get_nodes_in_group("ufos"):
		if is_instance_valid(enemy) and enemy is Node3D:
			var dist := global_position.distance_to(enemy.global_position)
			if dist <= blast_radius:
				print("💥🛸 Fala uderzeniowa bomby trafia UFO – zmniejszenie o 15% i przyspieszenie o 15%!")
				if enemy.has_method("on_hit_bomb"):
					enemy.call("on_hit_bomb")
				elif enemy.has_method("shrink_by_percent"):
					enemy.call("shrink_by_percent", 0.15)


func _on_body_entered(body: Node3D) -> void:
	if _has_exploded:
		return
	if body.is_in_group("player"):
		if _player_immunity_timer <= 0.0 and not _is_ticking:
			start_fuse(0.8)
	elif body.is_in_group("ufos"):
		detonate()


func _on_area_entered(area: Area3D) -> void:
	if _has_exploded:
		return
	# Zderzenie z UFO zmniejsza UFO o 15%, przyspiesza o 15% i detonuje bombę!
	if area.is_in_group("ufos") or area.has_method("on_hit_bomb") or area.name.to_lower().contains("ufo"):
		print("💥🛸 UFO najechało na bombę!")
		if area.has_method("on_hit_bomb"):
			area.call("on_hit_bomb")
		elif area.has_method("shrink_by_percent"):
			area.call("shrink_by_percent", 0.15)
		detonate()
