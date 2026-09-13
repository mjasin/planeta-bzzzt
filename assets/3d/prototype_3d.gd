class_name Prototype3D
extends Node3D

## Prototype3D - Główny zarządca sceny prototypu 3D dla gry "Planeta Bzzzt!"

signal level_won
signal game_over

const MAX_LIVES: int = 3

@export_group("Konfiguracja")
@export var ufo_chase_trigger_score: int = 2

@onready var camera: Camera3D = $Camera3D
@onready var player: Player3D = $PlayerInstance
@onready var planet: PlanetCentral3D = $PlanetCentral3D
@onready var ufo: Area3D = $UFO3D
@onready var score_label: Label = $CanvasLayer/UI/ScoreLabel
@onready var lives_label: Label = get_node_or_null("CanvasLayer/UI/LivesLabel")
@onready var hint_label: Label = $CanvasLayer/UI/HintLabel
@onready var fullscreen_button: Button = get_node_or_null("CanvasLayer/UI/FullscreenButton")
@onready var victory_container: Control = $CanvasLayer/UI/VictoryContainer
@onready var victory_label: Label = $CanvasLayer/UI/VictoryContainer/VictoryLabel
@onready var restart_button: Button = $CanvasLayer/UI/VictoryContainer/RestartButton
@onready var bomb_button: Button = get_node_or_null("CanvasLayer/UI/BombButton")
@onready var shield_button: Button = get_node_or_null("CanvasLayer/UI/ShieldButton")

var score: int = 0
var total_stars: int = 0
var current_lives: int = MAX_LIVES
var is_game_won: bool = false

var _camera_base_pos := Vector3.ZERO
var _shake_timer: float = 0.0
var _shake_strength: float = 0.0

func _ready() -> void:
	if camera:
		_camera_base_pos = camera.position
		
	_count_and_connect_stars()
	_connect_player_and_ufo()
	_connect_bombs()
	_update_ui()
	
	# Wszystkie UFO na planszy rozpoczynają pościg od razu od startu
	var target_to_chase = player if player != null else get_node_or_null("PlayerInstance")
	for u in get_tree().get_nodes_in_group("ufos"):
		if u.has_method("start_chasing"):
			u.call("start_chasing", target_to_chase)
	
	get_tree().node_added.connect(_on_node_added)
	
	if restart_button:
		restart_button.pressed.connect(restart_scene)
	if fullscreen_button:
		fullscreen_button.pressed.connect(toggle_fullscreen)
	if bomb_button and player:
		bomb_button.pressed.connect(player.drop_bomb)
	if shield_button and player:
		shield_button.button_down.connect(func(): player.touch_shield_pressed = true)
		shield_button.button_up.connect(func(): player.touch_shield_pressed = false)
		
	# Na desktopie bez dotyku ukrywamy przyciski dotykowe
	var has_touch: bool = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if not has_touch:
		if bomb_button: bomb_button.visible = false
		if shield_button: shield_button.visible = false


func _process(delta: float) -> void:
	# Obsługa trzęsienia kamery (Screen Shake) przy wybuchach bomb
	if _shake_timer > 0.0:
		_shake_timer -= delta
		if camera:
			var offset := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
			camera.position = _camera_base_pos + offset
		if _shake_timer <= 0.0 and camera:
			camera.position = _camera_base_pos


## Wywołuje soczyste trzęsienie ekranu (Juice)
func trigger_screen_shake(duration: float = 0.35, strength: float = 0.4) -> void:
	_shake_timer = duration
	_shake_strength = strength


func _connect_player_and_ufo() -> void:
	if player != null and not player.is_connected("exploded", _on_player_exploded):
		player.exploded.connect(_on_player_exploded)
	for u in get_tree().get_nodes_in_group("ufos"):
		if u.has_signal("hit_player") and not u.is_connected("hit_player", _on_player_hit_by_ufo):
			u.connect("hit_player", _on_player_hit_by_ufo)
		if u.has_signal("exploded") and not u.is_connected("exploded", _on_ufo_exploded):
			u.connect("exploded", _on_ufo_exploded)


func _on_ufo_exploded() -> void:
	trigger_screen_shake(0.55, 0.65)
	print(" 3D: UFO ZNISZCZONE PRZEZ BOMBĘ!")


func _connect_bombs() -> void:
	for b in get_tree().get_nodes_in_group("bombs"):
		_hook_bomb(b)


func _on_node_added(node: Node) -> void:
	if node is Bomb3D or node.is_in_group("bombs"):
		_hook_bomb(node)


func _hook_bomb(bomb_node: Node) -> void:
	if bomb_node.has_signal("exploded") and not bomb_node.is_connected("exploded", _on_bomb_exploded):
		bomb_node.connect("exploded", _on_bomb_exploded)


func _on_bomb_exploded(_pos: Vector3) -> void:
	trigger_screen_shake(0.35, 0.45)


func _count_and_connect_stars() -> void:
	total_stars = 0
	var stars_node := get_node_or_null("Stars")
	var star_list: Array = []
	if stars_node:
		star_list = stars_node.get_children()
	else:
		star_list = get_tree().get_nodes_in_group("stars")
		
	for child in star_list:
		if child.has_signal("collected"):
			total_stars += 1
			if not child.is_connected("collected", _on_star_collected):
				child.connect("collected", _on_star_collected)
	print(" Prototype3D: Połączono %d gwiazdek do zebrania!" % total_stars)


func _on_star_collected(points: int) -> void:
	if is_game_won or current_lives <= 0:
		return
		
	score += points
	_update_ui()
	_animate_score_pop()
	
	# Po zdobyciu wymaganej liczby gwiazdek UFO ruszają w pościg za graczem!
	if score >= ufo_chase_trigger_score and player != null:
		for u in get_tree().get_nodes_in_group("ufos"):
			if is_instance_valid(u) and u.has_method("start_chasing"):
				u.call("start_chasing", player)
		
	if score >= total_stars:
		_on_level_won()


func _on_player_hit_by_ufo() -> void:
	pass


func _on_player_exploded() -> void:
	if is_game_won or current_lives <= 0:
		return
		
	current_lives -= 1
	_update_ui()
	_animate_life_loss()
	trigger_screen_shake(0.4, 0.5)
	print("[ ] 3D: Gracz zniszczony! Pozostałe życia: %d / %d" % [current_lives, MAX_LIVES])
	
	# Odsunięcie wszystkich UFO od gracza po trafieniu
	for u in get_tree().get_nodes_in_group("ufos"):
		if is_instance_valid(u) and u is Node3D:
			u.stop_chasing()
		
	if current_lives <= 0:
		_on_game_over()
	else:
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(player) and not is_game_won and current_lives > 0:
				for u in get_tree().get_nodes_in_group("ufos"):
					if is_instance_valid(u) and u.has_method("start_chasing"):
						u.call("start_chasing", player)
		)


func _on_game_over() -> void:
	game_over.emit()
	print(" 3D GAME OVER! Utracono wszystkie życia!")
	if player:
		player.freeze()
	for u in get_tree().get_nodes_in_group("ufos"):
		if is_instance_valid(u) and u.has_method("freeze"):
			u.call("freeze")
		
	if victory_container:
		victory_container.visible = true
	if victory_label:
		victory_label.text = "KONIEC GRY! (3 PORAŻKI)"
		victory_label.add_theme_color_override("font_color", Color(3.5, 0.2, 0.2, 1.0))
		victory_label.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.0, 1.0))
		victory_label.scale = Vector2.ZERO
		victory_label.pivot_offset = victory_label.size / 2.0
		var tween := create_tween()
		tween.tween_property(victory_label, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(victory_label, "scale", Vector2.ONE, 0.2)
	if restart_button:
		restart_button.text = "Spróbuj ponownie"


func _on_level_won() -> void:
	is_game_won = true
	level_won.emit()
	if player:
		player.freeze()
	for u in get_tree().get_nodes_in_group("ufos"):
		if is_instance_valid(u) and u.has_method("freeze"):
			u.call("freeze")
	_show_victory_screen()


func _update_ui() -> void:
	if score_label:
		score_label.text = "Gwiazdki: %d / %d" % [score, total_stars]
		
	if lives_label:
		var hearts := ""
		for i in range(MAX_LIVES):
			if i < current_lives:
				hearts += "[x] "
			else:
				hearts += "[ ] "
		lives_label.text = "Życia: %s" % hearts.strip_edges()


func _animate_life_loss() -> void:
	if lives_label:
		lives_label.pivot_offset = lives_label.size / 2.0
		var tween := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		lives_label.add_theme_color_override("font_color", Color(3.5, 0.1, 0.1, 1.0))
		tween.tween_property(lives_label, "scale", Vector2(1.4, 1.4), 0.15)
		tween.tween_property(lives_label, "scale", Vector2.ONE, 0.25)


func _animate_score_pop() -> void:
	if score_label:
		score_label.pivot_offset = score_label.size / 2.0
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(score_label, "scale", Vector2(1.25, 1.25), 0.12)
		tween.tween_property(score_label, "scale", Vector2.ONE, 0.18)


func _show_victory_screen() -> void:
	if victory_container:
		victory_container.visible = true
	if victory_label:
		victory_label.text = "POZIOM 3D UKOŃCZONY!"
		victory_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.1, 1.0))
		victory_label.add_theme_color_override("font_outline_color", Color(0.9, 0.1, 1.2, 1.0))
		victory_label.scale = Vector2.ZERO
		victory_label.pivot_offset = victory_label.size / 2.0
		var tween := create_tween()
		tween.tween_property(victory_label, "scale", Vector2(1.2, 1.2), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(victory_label, "scale", Vector2.ONE, 0.2)
	if restart_button:
		restart_button.text = "Zagraj jeszcze raz"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			return

	if is_game_won or current_lives <= 0:
		if event.is_action_pressed("ui_accept"):
			restart_scene()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				restart_scene()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		restart_scene()


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print(" 3D: Zmieniono tryb na okienkowy")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print(" 3D: Zmieniono tryb na pełny ekran")


func restart_scene() -> void:
	get_tree().reload_current_scene()
