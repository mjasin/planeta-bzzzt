class_name Main
extends Node2D

## Main - Skrypt zarządcy gry ze środkową Mecha-Planetą "Planeta Bzzzt!", równomiernym rozmieszczeniem gwiazdek, obsługą pościgu i ekranem zwycięstwa.

# --- PROGRESJA POZIOMÓW (ZACHOWYWANA MIĘDZY PRZEŁADOWANIAMI SCENY) ---
static var current_level: int = 1
static var extra_stars: int = 0
static var meteor_speed_multiplier: float = 1.0

# --- PREFABRYKATY ---
const STAR_SCENE: PackedScene = preload("res://star.tscn")
const UFO_SCENE: PackedScene = preload("res://ufo.tscn")

# --- SYGNAŁY ---
signal level_won ## Emitowany po zebraniu wszystkich gwiazdek na planszy

# --- ZMIENNE EKSPORTOWANE ---
@export_group("Zasady Poziomu")
@export var target_stars_to_win: int = 0 ## Liczba gwiazdek do wygrania (0 = wszystkie na planszy)
@export var stars_increase_per_level: int = 1 ## Ile dodatkowych gwiazdek dodać na każdy kolejny poziom (+1, +2 itd.)
@export var meteor_speed_increase_factor: float = 1.1 ## Mnożnik prędkości meteoru po ukończeniu poziomu (+10%)

# --- REFERENCJE DO WĘZŁÓW ---
@onready var score_label: Label = $CanvasLayer/UI/ScoreLabel
@onready var player: CharacterBody2D = $Player
@onready var background_rect: ColorRect = $BackgroundLayer/ColorRect
@onready var ui_root: Control = $CanvasLayer/UI
@onready var victory_container: Control = get_node_or_null("CanvasLayer/UI/VictoryContainer")
@onready var victory_label: Label = get_node_or_null("CanvasLayer/UI/VictoryContainer/VictoryLabel")
@onready var restart_button: Button = get_node_or_null("CanvasLayer/UI/VictoryContainer/RestartButton")
@onready var restart_hint_label: Label = get_node_or_null("CanvasLayer/UI/VictoryContainer/RestartHintLabel")

# --- ZMIENNE STANU ---
var score: int = 0:
	set(value):
		score = value
		_update_ui()

var total_stars: int = 0
var stars_collected: int = 0
var is_game_won: bool = false

func _ready() -> void:
	randomize() # Inicjalizacja ziarna losowości
	_spawn_extra_stars()
	_spawn_extra_ufos()
	_apply_meteor_progression()
	_setup_world_environment()
	_setup_starfield_particles()
	_setup_ui_neon_style()
	_randomize_star_positions()
	_connect_stars()
	_count_total_stars()
	_connect_player()
	_setup_victory_ui()
	_update_ui()
	_trigger_ufo_chase()
	
	var total_ufos := get_tree().get_nodes_in_group("ufos").size()
	print("🌌 Planeta Bzzzt! Poziom %d | Gwiazdki: %d | Liczba UFO: %d | Mnożnik prędkości: x%.2f" % [current_level, total_stars, total_ufos, meteor_speed_multiplier])


## Tworzy dodatkowe UFO na każdy kolejny ukończony poziom w losowych, odrębnych miejscach planszy
func _spawn_extra_ufos() -> void:
	var extra_ufo_count: int = current_level - 1
	if extra_ufo_count <= 0:
		return
		
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1152, 648)
	var center := viewport_size / 2.0
	
	for i in extra_ufo_count:
		var new_ufo := UFO_SCENE.instantiate()
		new_ufo.name = "ExtraUFO_Lvl%d_%d" % [current_level, i + 1]
		
		# Znalezienie bezpiecznej, losowej pozycji oddalonej od innych UFO, gracza i planety
		var spawn_pos := _find_random_ufo_position(viewport_size, center)
		new_ufo.global_position = spawn_pos
		
		add_child(new_ufo)
		print("🛸 Przybyło NOWE UFO #%d na pozycji: %s!" % [i + 2, str(spawn_pos)])


## Wyszukuje bezpieczne, losowe miejsce dla nowego UFO
func _find_random_ufo_position(viewport_size: Vector2, center: Vector2) -> Vector2:
	var margin_x: float = 90.0
	var margin_y: float = 90.0
	var min_dist_from_center: float = 220.0
	var min_dist_from_player: float = 240.0
	var min_dist_from_other_ufos: float = 200.0
	
	var best_pos := Vector2(randf_range(margin_x, viewport_size.x - margin_x), randf_range(margin_y, viewport_size.y - margin_y))
	var attempts := 0
	
	while attempts < 100:
		attempts += 1
		var candidate := Vector2(randf_range(margin_x, viewport_size.x - margin_x), randf_range(margin_y, viewport_size.y - margin_y))
		
		# Odległość od środkowej planety
		if candidate.distance_to(center) < min_dist_from_center:
			continue
			
		# Odległość od pozycji gracza (zapobiega natychmiastowej kolizji po spawnie)
		if player != null and candidate.distance_to(player.global_position) < min_dist_from_player:
			continue
			
		# Odległość od innych UFO
		var too_close := false
		for ufo_node in get_tree().get_nodes_in_group("ufos"):
			if is_instance_valid(ufo_node) and ufo_node is Node2D:
				if candidate.distance_to(ufo_node.global_position) < min_dist_from_other_ufos:
					too_close = true
					break
		if too_close:
			continue
			
		return candidate
		
	return best_pos


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
	_clear_enemy_projectiles()
	reset_score()


## Usuwa wszystkie wrogie pociski z planszy
func _clear_enemy_projectiles() -> void:
	for proj in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(proj):
			proj.queue_free()


## Zeruje punkty i odtwarza ostrzegawczą animację w UI
func reset_score() -> void:
	score = 0
	print("💔 BZZZT! Stracono wszystkie zdobyte gwiazdki!")
	_stop_ufo_chase()
	_animate_score_reset()


## Włącza pościg dla wszystkich UFO na planszy
func _trigger_ufo_chase() -> void:
	for child in get_children():
		if child.has_method("start_chasing"):
			child.call("start_chasing", player)


func _trigger_meteor_chase() -> void:
	_trigger_ufo_chase()


## Zatrzymuje pościg wszystkich UFO na planszy
func _stop_ufo_chase() -> void:
	for child in get_children():
		if child.has_method("stop_chasing"):
			child.call("stop_chasing")


func _stop_meteor_chase() -> void:
	_stop_ufo_chase()


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
	env.glow_bloom = 0.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	world_env.environment = env
	add_child(world_env)


## Łączy sygnały od wszystkich gwiazdek na scenie
func _connect_stars() -> void:
	for child in get_children():
		if child.has_signal("collected"):
			child.connect("collected", _on_star_collected)


## Obsługuje zdarzenie zebrania gwiazdki
func _on_star_collected(points: int = 1) -> void:
	if is_game_won:
		return
		
	stars_collected += 1
	score += points # Wywoła setter score i _update_ui()
	_update_ui() # Zapewnia natychmiastowe odświeżenie UI i sprawdzenie warunku wygranej
	print("🏆 Aktualny wynik: %d | Gwiazdki: %d/%d" % [score, stars_collected, total_stars])
	
	_animate_score_pop()
	
	# Po zdobyciu co najmniej 2 gwiazdek UFO rozpoczyna pościg za graczem!
	if score >= 2:
		_trigger_ufo_chase()
	
	if score % 5 == 0 and player != null and player.has_method("apply_speed_boost"):
		print("🎉 SUPER BONUS za 5 gwiazdek!")
		player.call("apply_speed_boost", 1.8, 3.5)


## Tworzy dodatkowe gwiazdki dla kolejnych poziomów trudności
func _spawn_extra_stars() -> void:
	if extra_stars <= 0:
		return
	for i in extra_stars:
		var new_star := STAR_SCENE.instantiate()
		new_star.name = "ExtraStar_Lvl%d_%d" % [current_level, i + 1]
		add_child(new_star)


## Aplikuje zwiększoną prędkość do wszystkich UFO na planszy
func _apply_meteor_progression() -> void:
	if meteor_speed_multiplier <= 1.0:
		return
	for child in get_children():
		if child.has_method("apply_speed_multiplier"):
			child.call("apply_speed_multiplier", meteor_speed_multiplier)


## Oblicza całkowitą liczbę gwiazdek na planszy
func _count_total_stars() -> void:
	if target_stars_to_win > 0:
		total_stars = target_stars_to_win
	else:
		var star_nodes := get_tree().get_nodes_in_group("stars")
		total_stars = star_nodes.size()
		# Rezerwa: jeśli grupa nie była jeszcze zainicjalizowana, zlicz dzieci z sygnałem "collected"
		if total_stars == 0:
			for child in get_children():
				if child.has_signal("collected"):
					total_stars += 1


## Odświeża napis z liczbą punktów, numerem poziomu i postępem gwiazdek
func _update_ui() -> void:
	if score_label:
		if total_stars > 0:
			score_label.text = "Poziom %d | Gwiazdki: %d / %d" % [current_level, stars_collected, total_stars]
		else:
			score_label.text = "Poziom %d | Punkty: %d" % [current_level, score]
			
	# Sprawdzamy warunek ukończenia poziomu (Victory)
	if total_stars > 0 and stars_collected >= total_stars and not is_game_won:
		_on_level_won()


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
		
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1152, 648)
		
	# Warstwa 1: Wolny pył kosmiczny (ciemnoniebieski/fiolet)
	var cosmic_dust := CPUParticles2D.new()
	cosmic_dust.name = "CosmicDust"
	cosmic_dust.position = viewport_size / 2.0
	cosmic_dust.amount = 45
	cosmic_dust.lifetime = 6.0
	cosmic_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	cosmic_dust.emission_rect_extents = viewport_size / 2.0
	cosmic_dust.gravity = Vector2(0, 0)
	cosmic_dust.initial_velocity_min = 5.0
	cosmic_dust.initial_velocity_max = 15.0
	cosmic_dust.scale_amount_min = 1.0
	cosmic_dust.scale_amount_max = 3.0
	cosmic_dust.color = Color(0.3, 0.4, 0.9, 0.4)
	background_layer.add_child(cosmic_dust)
	cosmic_dust.emitting = true
	
	# Warstwa 2: Migoczące neonowe iskry
	var bright_sparks := CPUParticles2D.new()
	bright_sparks.name = "BrightSparks"
	bright_sparks.position = viewport_size / 2.0
	bright_sparks.amount = 35
	bright_sparks.lifetime = 4.0
	bright_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bright_sparks.emission_rect_extents = viewport_size / 2.0
	bright_sparks.gravity = Vector2(0, 0)
	bright_sparks.initial_velocity_min = 10.0
	bright_sparks.initial_velocity_max = 25.0
	bright_sparks.scale_amount_min = 2.0
	bright_sparks.scale_amount_max = 4.5
	
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.2, 1.5, 3.0, 0.8)) # Cyan
	gradient.add_point(0.5, Color(1.8, 0.3, 2.5, 0.9)) # Magenta
	gradient.set_color(gradient.get_point_count() - 1, Color(2.5, 2.5, 0.4, 0.8)) # Yellow
	bright_sparks.color_ramp = gradient
	
	background_layer.add_child(bright_sparks)
	bright_sparks.emitting = true


# ==============================================================================
# OBSŁUGA ZWYCIĘSTWA I ZAKOŃCZENIA POZIOMU (VICTORY JUICE)
# ==============================================================================

## Wywoływana po zebraniu ostatniej wymaganej gwiazdki
func _on_level_won() -> void:
	if is_game_won:
		return
	is_game_won = true
	level_won.emit()
	print("🏆 BRAWO! Wszystkie gwiazdki zebrane! POZIOM UKOŃCZONY!")
	
	# 1. Zatrzymanie ruchu gracza oraz przeszkód (meteorów / UFO)
	_freeze_gameplay()
	
	# 2. Wyświetlenie napisu z soczystym efektem Tween (juice)
	_show_victory_screen()
	
	# 3. Dynamiczny wybuch konfetti i deszcz gwiazd
	_spawn_victory_confetti()


## Zatrzymuje gracza i wszelkie ruchome przeszkody (meteory / UFO) oraz usuwa pociski
func _freeze_gameplay() -> void:
	_clear_enemy_projectiles()
	if player != null and player.has_method("freeze"):
		player.call("freeze")
	for child in get_children():
		if child.has_method("freeze"):
			child.call("freeze")


## Inicjalizuje elementy interfejsu zwycięstwa (dynamicznie lub z drzewa sceny)
func _setup_victory_ui() -> void:
	if victory_container == null and ui_root != null:
		victory_container = Control.new()
		victory_container.name = "VictoryContainer"
		victory_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui_root.add_child(victory_container)
		
		victory_label = Label.new()
		victory_label.name = "VictoryLabel"
		victory_label.text = "POZIOM UKOŃCZONY! BRAWO!"
		victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		victory_label.set_anchors_preset(Control.PRESET_CENTER)
		victory_label.offset_left = -450.0
		victory_label.offset_top = -120.0
		victory_label.offset_right = 450.0
		victory_label.offset_bottom = -20.0
		victory_container.add_child(victory_label)
		
		restart_button = Button.new()
		restart_button.name = "RestartButton"
		restart_button.text = "🚀 Zagraj jeszcze raz 🚀"
		restart_button.set_anchors_preset(Control.PRESET_CENTER)
		restart_button.offset_left = -175.0
		restart_button.offset_top = 10.0
		restart_button.offset_right = 175.0
		restart_button.offset_bottom = 75.0
		victory_container.add_child(restart_button)
		
		restart_hint_label = Label.new()
		restart_hint_label.name = "RestartHintLabel"
		restart_hint_label.text = "(Naciśnij SPACJĘ lub ENTER aby zagrać ponownie)"
		restart_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		restart_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		restart_hint_label.set_anchors_preset(Control.PRESET_CENTER)
		restart_hint_label.offset_left = -320.0
		restart_hint_label.offset_top = 85.0
		restart_hint_label.offset_right = 320.0
		restart_hint_label.offset_bottom = 120.0
		victory_container.add_child(restart_hint_label)

	# Stylizacja napisu zwycięstwa
	if victory_label:
		victory_label.add_theme_font_size_override("font_size", 54)
		victory_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.1, 1.0))
		victory_label.add_theme_color_override("font_outline_color", Color(0.9, 0.1, 1.2, 1.0))
		victory_label.add_theme_constant_override("outline_size", 16)
		victory_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
		victory_label.add_theme_constant_override("shadow_offset_x", 5)
		victory_label.add_theme_constant_override("shadow_offset_y", 5)

	# Stylizacja i podłączenie przycisku restartu
	if restart_button:
		restart_button.add_theme_font_size_override("font_size", 26)
		restart_button.focus_mode = Control.FOCUS_NONE
		if not restart_button.pressed.is_connected(restart_game):
			restart_button.pressed.connect(restart_game)

	# Stylizacja podpowiedzi klawiszowej
	if restart_hint_label:
		restart_hint_label.add_theme_font_size_override("font_size", 18)
		restart_hint_label.add_theme_color_override("font_color", Color(0.6, 1.2, 2.0, 0.9))

	if victory_container:
		victory_container.visible = false


## Efekt wyświetlenia ekranu zwycięstwa z animacją Tween (juice)
func _show_victory_screen() -> void:
	if victory_container == null:
		return
		
	victory_container.visible = true
	
	if victory_label:
		victory_label.text = "POZIOM %d UKOŃCZONY! BRAWO!" % current_level
		victory_label.visible = true
		victory_label.scale = Vector2.ZERO
		victory_label.pivot_offset = victory_label.size / 2.0
		
		# Płynne powiększenie od 0.0 do 1.25, a następnie powrót do 1.0 ze sprężynowaniem (Ease Out Back / Bounce)
		var tween := create_tween()
		tween.set_parallel(false)
		tween.tween_property(victory_label, "scale", Vector2(1.25, 1.25), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(victory_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
		# Wesołe kołysanie napisu na boki (soczysty efekt dla dzieci!)
		var wobble_tween := create_tween().set_loops()
		wobble_tween.tween_property(victory_label, "rotation", deg_to_rad(3.0), 0.5).set_trans(Tween.TRANS_SINE)
		wobble_tween.tween_property(victory_label, "rotation", deg_to_rad(-3.0), 0.5).set_trans(Tween.TRANS_SINE)
		
	if restart_button:
		var next_ufo_count: int = current_level + 1
		restart_button.text = "🚀 Poziom %d (+1 UFO 🛸, +%d ⭐) 🚀" % [current_level + 1, stars_increase_per_level]
		restart_button.visible = true
		restart_button.scale = Vector2.ZERO
		restart_button.pivot_offset = restart_button.size / 2.0
		var btn_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		btn_tween.tween_interval(0.35)
		btn_tween.tween_property(restart_button, "scale", Vector2.ONE, 0.35)
		
	if restart_hint_label:
		restart_hint_label.text = "(Naciśnij SPACJĘ lub ENTER aby rozpocząć Poziom %d)" % (current_level + 1)
		restart_hint_label.visible = true
		restart_hint_label.modulate.a = 0.0
		var hint_tween := create_tween()
		hint_tween.tween_interval(0.55)
		hint_tween.tween_property(restart_hint_label, "modulate:a", 1.0, 0.4)


## Wybuch konfetti oraz deszcz gwiazd za pomocą CPUParticles2D
func _spawn_victory_confetti() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1152, 648)
	var center := viewport_size / 2.0
	
	# 1. Wybuch konfetti w centrum ekranu
	var confetti := CPUParticles2D.new()
	confetti.name = "VictoryConfetti"
	confetti.position = center
	confetti.amount = 140
	confetti.lifetime = 3.5
	confetti.one_shot = true
	confetti.explosiveness = 0.95
	confetti.spread = 180.0
	confetti.gravity = Vector2(0, 180)
	confetti.initial_velocity_min = 180.0
	confetti.initial_velocity_max = 420.0
	confetti.scale_amount_min = 4.0
	confetti.scale_amount_max = 10.0
	
	var confetti_gradient := Gradient.new()
	confetti_gradient.set_color(0, Color(3.5, 0.3, 1.2, 1.0))
	confetti_gradient.add_point(0.3, Color(0.2, 3.0, 3.5, 1.0))
	confetti_gradient.add_point(0.6, Color(3.5, 3.2, 0.2, 1.0))
	confetti_gradient.set_color(confetti_gradient.get_point_count() - 1, Color(0.3, 3.5, 0.8, 0.0))
	confetti.color_ramp = confetti_gradient
	
	add_child(confetti)
	confetti.emitting = true
	
	# 2. Deszcz złotych gwiazdek opadających z góry
	var star_rain := CPUParticles2D.new()
	star_rain.name = "VictoryStarRain"
	star_rain.position = Vector2(center.x, -20)
	star_rain.amount = 75
	star_rain.lifetime = 4.0
	star_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	star_rain.emission_rect_extents = Vector2(viewport_size.x / 2.0, 10)
	star_rain.direction = Vector2(0, 1)
	star_rain.spread = 15.0
	star_rain.gravity = Vector2(0, 140)
	star_rain.initial_velocity_min = 90.0
	star_rain.initial_velocity_max = 220.0
	star_rain.scale_amount_min = 5.0
	star_rain.scale_amount_max = 11.0
	star_rain.color = Color(3.5, 3.2, 0.3, 0.9) # Golden Star Glow
	add_child(star_rain)
	star_rain.emitting = true


## Obsługa klawiatury – Space/Enter przechodzi do kolejnego poziomu, 'R' resetuje do poziomu 1
func _unhandled_input(event: InputEvent) -> void:
	if is_game_won:
		if event.is_action_pressed("ui_accept"):
			restart_game()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				restart_game()
	else:
		# Klawisz R pozwala zresetować grę do poziomu 1 w dowolnym momencie
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			reset_progression()
			get_tree().reload_current_scene()


## Przechodzi do kolejnego poziomu ze zwiększoną trudnością (nowe UFO w losowym miejscu, więcej gwiazdek, szybsze UFO)
func restart_game() -> void:
	if is_game_won:
		current_level += 1
		extra_stars += stars_increase_per_level
		meteor_speed_multiplier *= meteor_speed_increase_factor
		print("🚀 Start Poziomu %d! Liczba UFO: %d, Dodano gwiazdek: +%d, nowa prędkość: x%.2f" % [current_level, current_level, extra_stars, meteor_speed_multiplier])
	get_tree().reload_current_scene()


## Resetuje całą progresję trudności z powrotem do Poziomu 1 (np. pod klawiszem 'R')
static func reset_progression() -> void:
	current_level = 1
	extra_stars = 0
	meteor_speed_multiplier = 1.0
	print("🔄 Zresetowano grę do Poziomu 1 (1 bazowe UFO)!")
