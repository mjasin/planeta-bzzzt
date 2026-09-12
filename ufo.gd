class_name UFO
extends Area2D

## UFO - Zły latający spodek kosmitów, który ściga gracza po planszy Mecha-Planety.

# --- ZMIENNE EKSPORTOWANE ---
@export var follow_speed: float = 135.0 ## Prędkość podążania za graczem
@export var is_chasing_player: bool = true ## Czy UFO aktywnie śledzi gracza

@export_group("Obrót / Kręcenie się")
@export var is_spinning_crazy: bool = true ## Czy UFO szybko się kręci wokół własnej osi
@export var spin_speed: float = 7.5 ## Prędkość obrotu spodka (rad/s)
@export var tilt_amount: float = 0.35 ## Przechem przy skręcie (gdy is_spinning_crazy = false)
@export var wobble_speed: float = 6.0 ## Prędkość lewitacji spodka
@export var wobble_amount: float = 6.0 ## Amplituda lewitacji

@export_group("Strzelanie Lasera")
@export var can_shoot: bool = true ## Czy UFO strzela do bohatera
@export var shoot_interval: float = 0.45 ## Ciągły ostrzał (czas w sekundach pomiędzy strzałami)
@export var laser_scene: PackedScene = preload("res://laser_enemy.tscn")

# --- REFERENCJE DO WĘZŁÓW ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# --- ZMIENNE PRYWATNE ---
var target_player: CharacterBody2D = null
var _anim_time: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _spawn_position: Vector2
var is_frozen: bool = false
var is_charging_shot: bool = false
var _shoot_timer: float = 0.0
var _thruster_particles: CPUParticles2D

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("ufos")
	_base_scale = scale
	_spawn_position = global_position
	body_entered.connect(_on_body_entered)
	_setup_thruster_particles()
	_setup_alien_glow()
	print("🛸 SZALONE UFO (kręci się i stale strzela) pojawiło się na orbicie!")


func _process(delta: float) -> void:
	if is_frozen:
		return
		
	_anim_time += delta * wobble_speed
	if not is_charging_shot:
		_apply_alien_glow()
		
	# Ciągły szalony obrót spodka wokół własnej osi
	if is_spinning_crazy:
		rotation += spin_speed * delta
	
	if is_chasing_player:
		if target_player == null:
			_find_player()
		if target_player != null:
			_chase_player(delta)
			
			# Ciągłe strzelanie w stronę bohatera
			if can_shoot:
				_shoot_timer += delta
				if _shoot_timer >= shoot_interval:
					_shoot_timer = 0.0
					_shoot_continuous_laser()
	else:
		position.y += sin(_anim_time) * 0.4


## Wyszukuje gracza w drzewie sceny
func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is CharacterBody2D:
		target_player = players[0]
	else:
		var candidate = get_parent().get_node_or_null("Player")
		if candidate is CharacterBody2D:
			target_player = candidate


## Ruch pościgu w stronę gracza z efektem przechylania kadłuba
func _chase_player(delta: float) -> void:
	if target_player == null:
		return
		
	var direction := (target_player.global_position - global_position).normalized()
	global_position += direction * follow_speed * delta
	
	# Przechylenie spodka w stronę lotu tylko jeśli nie wiruje szaleńczo
	if not is_spinning_crazy:
		var target_tilt := direction.x * tilt_amount
		rotation = lerp_angle(rotation, target_tilt, delta * 7.0)
	
	# Delikatne pulsowanie lewitacji
	var pulse := sin(_anim_time) * 0.04
	scale = _base_scale * Vector2(1.0 + pulse, 1.0 - pulse)


## Mroczna, złowieszcza neonowa poświata kosmitów (Czerwień i Karmin HDR)
func _setup_alien_glow() -> void:
	if sprite:
		sprite.modulate = Color(1.3, 1.0, 1.2, 1.0)


func _apply_alien_glow() -> void:
	if sprite:
		var pulse: float = (sin(_anim_time * 2.0) + 1.0) * 0.5
		var glow_color := Color(1.4 + pulse * 0.6, 0.8 + pulse * 0.2, 1.2 + pulse * 0.5, 1.0)
		sprite.modulate = glow_color


## Efekt napędu plazmowego pod spodkiem
func _setup_thruster_particles() -> void:
	_thruster_particles = CPUParticles2D.new()
	_thruster_particles.name = "ThrusterParticles"
	_thruster_particles.position = Vector2(0, 18)
	_thruster_particles.amount = 30
	_thruster_particles.lifetime = 0.45
	_thruster_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_thruster_particles.emission_rect_extents = Vector2(14, 4)
	_thruster_particles.direction = Vector2(0, 1)
	_thruster_particles.spread = 25.0
	_thruster_particles.gravity = Vector2(0, 80)
	_thruster_particles.initial_velocity_min = 60.0
	_thruster_particles.initial_velocity_max = 140.0
	_thruster_particles.scale_amount_min = 3.0
	_thruster_particles.scale_amount_max = 7.0
	
	var gradient := Gradient.new()
	gradient.set_color(0, Color(3.5, 0.2, 0.6, 1.0))   # Ognisty róż / czerwień HDR
	gradient.add_point(0.4, Color(3.0, 1.8, 0.2, 0.9)) # Neonowy żółty
	gradient.set_color(gradient.get_point_count() - 1, Color(0.2, 1.5, 3.5, 0.0))
	_thruster_particles.color_ramp = gradient
	
	add_child(_thruster_particles)
	_thruster_particles.emitting = true


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		print("💥 BZZZT! ZŁE UFO DOPADŁO GRACZA!")
		if body is CharacterBody2D:
			target_player = body
		_on_player_hit(body)


func _on_player_hit(player_node: Node2D) -> void:
	if player_node.has_method("explode"):
		player_node.call("explode")
		
	# Zwycięski wstrząs i obrót UFO po trafieniu gracza
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _base_scale * 1.4, 0.15)
	tween.tween_property(self, "scale", _base_scale, 0.2)
	
	reset_to_spawn()


## Cofa UFO na pozycję startową i daje graczowi 1.6s czasu na ucieczkę po odrodzeniu
func reset_to_spawn() -> void:
	is_chasing_player = false
	rotation = 0.0
	_shoot_timer = 0.0 # Resetujemy licznik strzałów, aby nie strzelić od razu w odradzającego się gracza
	
	# Płynny powrót spodka na pozycję startową
	var return_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return_tween.tween_property(self, "global_position", _spawn_position, 0.6)
	
	await get_tree().create_timer(1.6).timeout
	if not is_frozen:
		start_chasing()


## Ciągłe, szybkie wystrzeliwanie laserów plazmowych w stronę gracza
func _shoot_continuous_laser() -> void:
	if is_frozen or target_player == null or laser_scene == null:
		return
		
	var spawn_pos: Vector2 = global_position
	var base_dir: Vector2 = (target_player.global_position - spawn_pos).normalized()
	# Szeroki kąt rozrzutu pocisków (+/- 12 stopni) dla wspaniałego efektu salwy
	var spread_angle: float = randf_range(-0.22, 0.22)
	var shoot_dir: Vector2 = base_dir.rotated(spread_angle)
	
	var laser_instance := laser_scene.instantiate()
	get_parent().add_child(laser_instance)
	if laser_instance.has_method("initialize"):
		laser_instance.call("initialize", spawn_pos, shoot_dir)
		
	# Błysk impulsowy kokpitu UFO przy każdym wystrzale
	if sprite:
		sprite.modulate = Color(3.5, 3.0, 0.5, 1.0)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1.3, 0.9, 1.2, 1.0), 0.1)


# ==============================================================================
# METODY KOMPATYBILNOŚCI I PROMPTÓW NA ŻYWO (VIBE CODING)
# ==============================================================================

func start_chasing(player_ref: CharacterBody2D = null) -> void:
	if player_ref != null:
		target_player = player_ref
	is_chasing_player = true
	print("🛸 ZŁE UFO rozpoczęło pościg za graczem!")


func stop_chasing() -> void:
	is_chasing_player = false
	print("🛑 UFO tymczasowo zatrzymało pościg.")


func freeze() -> void:
	is_frozen = true
	stop_chasing()
	_shoot_timer = 0.0
	if _thruster_particles:
		_thruster_particles.emitting = false


func unfreeze() -> void:
	is_frozen = false
	start_chasing()
	_shoot_timer = 0.0
	if _thruster_particles:
		_thruster_particles.emitting = true


func apply_speed_multiplier(multiplier: float) -> void:
	follow_speed *= multiplier
	print("🛸 Nowa prędkość UFO: %.1f (mnożnik: x%.2f)" % [follow_speed, multiplier])


func spin_crazy(extra_turns: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(self, "rotation", rotation + TAU * extra_turns, 0.4)
