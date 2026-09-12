class_name Portal
extends Area2D

## Portal - Kosmiczny wir teleportujący gracza w losowe, bezpieczne miejsce na planszy.

signal player_teleported(from_pos: Vector2, to_pos: Vector2)

# --- ZMIENNE EKSPORTOWANE ---
@export var spin_speed: float = 2.8 ## Prędkość wirowania portalu w radianach na sekundę
@export var pulse_speed: float = 4.5 ## Szybkość pulsowania
@export var cooldown_time: float = 1.6 ## Czas w sekundach na odnowienie gotowości portalu

# --- REFERENCJE DO WĘZŁÓW ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# --- ZMIENNE PRYWATNE ---
var _base_scale: Vector2 = Vector2.ONE
var _anim_time: float = 0.0
var _is_ready: bool = true
var _vortex_particles: CPUParticles2D

func _ready() -> void:
	add_to_group("portals")
	_base_scale = scale
	body_entered.connect(_on_body_entered)
	_setup_vortex_particles()
	_setup_portal_glow()
	print("🌀 Portal kwantowy otwarty i aktywny na planszy!")


func _process(delta: float) -> void:
	_anim_time += delta * pulse_speed
	
	# Płynny obrót wiru
	rotation += spin_speed * delta
	
	# Pulsowanie oddychania portalu
	var pulse: float = sin(_anim_time) * 0.08
	scale = _base_scale * (1.0 + pulse)


func _setup_portal_glow() -> void:
	if sprite:
		sprite.modulate = Color(1.2, 1.8, 3.5, 1.0)


func _setup_vortex_particles() -> void:
	_vortex_particles = CPUParticles2D.new()
	_vortex_particles.name = "VortexParticles"
	_vortex_particles.amount = 35
	_vortex_particles.lifetime = 1.4
	_vortex_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	_vortex_particles.emission_ring_radius = 42.0
	_vortex_particles.emission_ring_inner_radius = 18.0
	_vortex_particles.gravity = Vector2.ZERO
	_vortex_particles.orbit_velocity_min = 1.2
	_vortex_particles.orbit_velocity_max = 2.2
	_vortex_particles.scale_amount_min = 3.0
	_vortex_particles.scale_amount_max = 6.0
	_vortex_particles.color = Color(0.2, 2.8, 3.5, 0.8) # Neon Cyan
	add_child(_vortex_particles)
	_vortex_particles.emitting = true


func _on_body_entered(body: Node2D) -> void:
	if not _is_ready:
		return
		
	if body.is_in_group("player") or body.name == "Player":
		teleport_player(body)


## Przeprowadza pełną procedurę teleportacji gracza z animacjami wejścia i wyjścia
func teleport_player(player_node: Node2D) -> void:
	_is_ready = false
	var origin_pos := player_node.global_position
	print("🌀 BZZZT! Gracz wszedł do portalu kwantowego!")
	
	# 1. Efekt zapadania się (implozja) gracza w portalu
	var player_base_scale := Vector2.ONE
	if "scale" in player_node:
		player_base_scale = player_node.scale
		var in_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		in_tween.tween_property(player_node, "scale", Vector2.ZERO, 0.15)
		
	# Błysk portalu i rozbryk cząsteczek na wejściu
	_spawn_teleport_particles(global_position, Color(0.2, 3.0, 3.5, 1.0))
	if sprite:
		sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
		
	await get_tree().create_timer(0.16).timeout
	
	# 2. Losowanie nowej, bezpiecznej pozycji na planszy
	var target_pos := _find_random_safe_position(origin_pos)
	player_node.global_position = target_pos
	
	# 3. Wybuch cząsteczek i eksplozja pojawienia się gracza na wyjściu
	_spawn_teleport_particles(target_pos, Color(2.5, 0.4, 3.5, 1.0)) # Magiczny fiolet/róż na wyjściu
	
	if "scale" in player_node:
		var out_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		out_tween.tween_property(player_node, "scale", player_base_scale * 1.35, 0.14)
		out_tween.tween_property(player_node, "scale", player_base_scale, 0.12)
		
	if player_node.has_method("set_flash_color"):
		player_node.call("set_flash_color", Color(0.3, 3.0, 3.5, 1.0))
		
	player_teleported.emit(origin_pos, target_pos)
	print("✨ Teleportacja ukończona! Nowa pozycja gracza: ", target_pos)
	
	# 4. Stan ładowania portalu (cooldown)
	if sprite:
		sprite.modulate = Color(0.5, 0.8, 1.2, 0.4) # Przygaszony podczas ładowania
	if _vortex_particles:
		_vortex_particles.emitting = false
		
	await get_tree().create_timer(cooldown_time).timeout
	
	# Ponowna gotowość portalu
	_setup_portal_glow()
	if _vortex_particles:
		_vortex_particles.emitting = true
		
	# Błysk gotowości
	var ready_tween := create_tween()
	ready_tween.tween_property(self, "scale", _base_scale * 1.25, 0.1)
	ready_tween.tween_property(self, "scale", _base_scale, 0.15)
	
	_is_ready = true
	print("⚡ Portal kwantowy naładowany i gotowy do użycia!")


## Oblicza bezpieczne, losowe współrzędne na planszy z dala od środka i wrogów
func _find_random_safe_position(from_pos: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1152, 648)
		
	var center := viewport_size / 2.0
	var min_dist_from_center: float = 200.0
	var min_dist_from_origin: float = 240.0
	var margin: float = 90.0
	
	var candidate_pos := from_pos
	var attempts := 0
	var best_pos := Vector2(randf_range(margin, viewport_size.x - margin), randf_range(margin, viewport_size.y - margin))
	
	while attempts < 30:
		attempts += 1
		var rand_x := randf_range(margin, viewport_size.x - margin)
		var rand_y := randf_range(margin, viewport_size.y - margin)
		candidate_pos = Vector2(rand_x, rand_y)
		
		# Nie za blisko środka Mecha-Planety
		if candidate_pos.distance_to(center) < min_dist_from_center:
			continue
			
		# Nie w to samo miejsce, z którego uciekamy
		if candidate_pos.distance_to(from_pos) < min_dist_from_origin:
			continue
			
		# Nie za blisko wrogów (UFO)
		var too_close_to_enemy := false
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and candidate_pos.distance_to(enemy.global_position) < 180.0:
				too_close_to_enemy = true
				break
		if too_close_to_enemy:
			continue
			
		best_pos = candidate_pos
		break
		
	return best_pos


## Tworzy błyskający rozbłysk cząsteczek przy wejściu i wyjściu z portalu
func _spawn_teleport_particles(at_pos: Vector2, color_tint: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = at_pos
	particles.amount = 40
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 240.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 9.0
	
	var gradient := Gradient.new()
	gradient.set_color(0, color_tint)
	gradient.add_point(0.5, Color(1.0, 1.0, 1.0, 1.0)) # Biały rdzeń błysku
	gradient.set_color(gradient.get_point_count() - 1, Color(color_tint.r, color_tint.g, color_tint.b, 0.0))
	particles.color_ramp = gradient
	
	get_parent().add_child(particles)
	particles.emitting = true
