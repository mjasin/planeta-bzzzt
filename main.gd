class_name Main
extends Node2D

## Main - Skrypt zarządcy gry ze środkową Mecha-Planetą "Planeta Bzzzt!", równomiernym rozmieszczeniem gwiazdek i obsługą wybuchu oraz pościgu.

# --- REFERENCJE DO WĘZŁÓW ---
@onready var score_label: Label = $CanvasLayer/UI/ScoreLabel
@onready var player: CharacterBody2D = $Player
@onready var background_rect: ColorRect = $BackgroundLayer/ColorRect

# --- ZMIENNE STANU ---
var score: int = 0:
	set(value):
		score = value
		_update_ui()

func _ready() -> void:
	randomize() # Inicjalizacja ziarna losowości
	_setup_world_environment()
	_setup_starfield_particles()
	_setup_ui_neon_style()
	_randomize_star_positions()
	_connect_stars()
	_connect_player()
	_update_ui()
	print("🌌 Neonowa gra Planeta Bzzzt! uruchomiona!")


## Rozrzuca wszystkie gwiazdki na scenie równomiernie wokół planety, zapobiegając nakładaniu się
func _randomize_star_positions() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1152, 648)
		
	var center := viewport_size / 2.0
	var min_dist_from_center: float = 230.0
	var min_dist_between_stars: float = 140.0
	var margin_x: float = 100.0
	var margin_y: float = 100.0
	
	var placed_positions: Array[Vector2] = []
	
	for child in get_children():
		if child.has_signal("collected"): # Zbieralne gwiazdki
			var new_pos: Vector2
			var valid := false
			var attempts := 0
			
			while not valid and attempts < 100:
				attempts += 1
				var rand_x := randf_range(margin_x, viewport_size.x - margin_x)
				var rand_y := randf_range(margin_y, viewport_size.y - margin_y)
				new_pos = Vector2(rand_x, rand_y)
				
				# Sprawdzamy odległość od środka planety i od gracza
				if new_pos.distance_to(center) < min_dist_from_center:
					continue
				if player != null and new_pos.distance_to(player.global_position) < 180.0:
					continue
					
				# Sprawdzamy odległość od pozostałych gwiazdek (zapobiega gęstym klastrom)
				var too_close := false
				for prev_pos in placed_positions:
					if new_pos.distance_to(prev_pos) < min_dist_between_stars:
						too_close = true
						break
				if too_close:
					continue
					
				valid = true
				
			placed_positions.append(new_pos)
			
			if child.has_method("set_star_position"):
				child.call("set_star_position", new_pos)
			else:
				child.position = new_pos


## Podłącza sygnał wybuchu gracza
func _connect_player() -> void:
	if player != null and player.has_signal("exploded"):
		player.connect("exploded", _on_player_exploded)


## Reakcja na wybuch gracza – wyzerowanie wyniku i efekt utraty gwiazdek
func _on_player_exploded() -> void:
	reset_score()


## Zeruje punkty i odtwarza ostrzegawczą animację w UI
func reset_score() -> void:
	score = 0
	print("💔 BZZZT! Stracono wszystkie zdobyte gwiazdki!")
	_stop_meteor_chase()
	_animate_score_reset()


## Włącza pościg dla meteorów
func _trigger_meteor_chase() -> void:
	for child in get_children():
		if child.has_method("start_chasing"):
			child.call("start_chasing", player)


## Zatrzymuje pościg meteorów
func _stop_meteor_chase() -> void:
	for child in get_children():
		if child.has_method("stop_chasing"):
			child.call("stop_chasing")


## Animacja utraty punktów (czerwone błyskanie i potrząśnięcie napisem)
func _animate_score_reset() -> void:
	if score_label:
		score_label.pivot_offset = score_label.size / 2.0
		var tween := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		score_label.add_theme_color_override("font_color", Color(3.5, 0.2, 0.2, 1.0))
		tween.tween_property(score_label, "scale", Vector2(1.5, 1.5), 0.15)
		tween.tween_property(score_label, "scale", Vector2.ONE, 0.25)
		
		await tween.finished
		_setup_ui_neon_style()


## Włącza poświatę Glow w WorldEnvironment
func _setup_world_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_strength = 1.1
	env.glow_bloom = 0.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	world_env.environment = env
	add_child(world_env)


## Dodaje punkty i odpala dynamiczne efekty w UI
func add_score(amount: int = 1) -> void:
	score += amount
	print("🏆 Aktualny wynik: ", score)
	
	_animate_score_pop()
	
	# Po zdobyciu co najmniej 2 gwiazdek meteor rozpoczyna pościg za graczem!
	if score >= 2:
		_trigger_meteor_chase()
	
	if score % 5 == 0 and player != null and player.has_method("apply_speed_boost"):
		print("🎉 SUPER BONUS za 5 gwiazdek!")
		player.call("apply_speed_boost", 1.8, 3.5)


## Odświeża napis z liczbą punktów
func _update_ui() -> void:
	if score_label:
		score_label.text = "Gwiazdki: %d" % score


## Nadaje etykiecie licznika neonowy żółty kolor z zieloną poświatą
func _setup_ui_neon_style() -> void:
	if score_label:
		score_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2, 1.0))
		score_label.add_theme_color_override("font_outline_color", Color(0.2, 3.0, 0.5, 1.0))
		score_label.add_theme_constant_override("outline_size", 12)


## Animacja wyskakiwania licznika punktów
func _animate_score_pop() -> void:
	if score_label:
		score_label.pivot_offset = score_label.size / 2.0
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(score_label, "scale", Vector2(1.25, 1.25), 0.12)
		tween.tween_property(score_label, "scale", Vector2.ONE, 0.18)


## Tworzy wielokolorowy system gwiazd i pyłu kosmicznego
func _setup_starfield_particles() -> void:
	var background_layer := get_node_or_null("BackgroundLayer")
	if background_layer == null:
		return
		
	var blue_stars := CPUParticles2D.new()
	blue_stars.name = "BlueStars"
	blue_stars.position = Vector2(576, -20)
	blue_stars.amount = 50
	blue_stars.lifetime = 10.0
	blue_stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	blue_stars.emission_rect_extents = Vector2(650, 10)
	blue_stars.direction = Vector2(0, 1)
	blue_stars.spread = 5.0
	blue_stars.gravity = Vector2(0, 0)
	blue_stars.initial_velocity_min = 10.0
	blue_stars.initial_velocity_max = 35.0
	blue_stars.scale_amount_min = 2.0
	blue_stars.scale_amount_max = 5.0
	blue_stars.color = Color(0.3, 1.8, 3.5, 0.8)
	background_layer.add_child(blue_stars)
	blue_stars.emitting = true
	
	var pink_dust := CPUParticles2D.new()
	pink_dust.name = "PinkDust"
	pink_dust.position = Vector2(576, -20)
	pink_dust.amount = 35
	pink_dust.lifetime = 12.0
	pink_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pink_dust.emission_rect_extents = Vector2(650, 10)
	pink_dust.direction = Vector2(0, 1)
	pink_dust.spread = 10.0
	pink_dust.gravity = Vector2(0, 0)
	pink_dust.initial_velocity_min = 8.0
	pink_dust.initial_velocity_max = 25.0
	pink_dust.scale_amount_min = 3.0
	pink_dust.scale_amount_max = 7.0
	pink_dust.color = Color(2.5, 0.4, 2.0, 0.6)
	background_layer.add_child(pink_dust)
	pink_dust.emitting = true


## Łączy sygnały zbieralnych gwiazdek
func _connect_stars() -> void:
	for child in get_children():
		if child.has_signal("collected"):
			child.connect("collected", _on_star_collected)


func _on_star_collected(points: int) -> void:
	add_score(points)


func restart_game() -> void:
	get_tree().reload_current_scene()
