class_name BzzztVirtualJoystick
extends Control

## BzzztVirtualJoystick - Kosmiczny wirtualny joystick dotykowy (Floating & Fixed)
## Automatycznie emuluje akcje: ui_left, ui_right, ui_up, ui_down

@export var max_radius: float = 70.0 ## Maksymalne wychylenie gałki w pikselach
@export var deadzone: float = 12.0 ## Martwa strefa (poniżej gracz stoi)
@export var auto_hide_on_desktop: bool = false ## Czy ukrywać na desktopie bez dotyku

var _touch_index: int = -1
var _center_pos: Vector2 = Vector2.ZERO
var _current_pos: Vector2 = Vector2.ZERO
var _is_active: bool = false
var _output_vector: Vector2 = Vector2.ZERO

var _base_rect: Rect2
var _default_center: Vector2

# Kolory neonowe
var _color_ring: Color = Color(0.0, 0.83, 1.0, 0.4) # Neon blue
var _color_glow: Color = Color(0.66, 0.33, 0.97, 0.25) # Neon purple
var _color_knob: Color = Color(0.0, 0.83, 1.0, 0.85)

func _ready() -> void:
	# Ustawiamy domyślny środek joysticka (np. 140px od lewej, 140px od dołu)
	custom_minimum_size = Vector2(200, 200)
	_default_center = size / 2.0
	_center_pos = _default_center
	_current_pos = _default_center
	
	# Jeśli wykryto urządzenie dotykowe lub mobile
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if auto_hide_on_desktop and not is_mobile and not DisplayServer.is_touchscreen_available():
		modulate.a = 0.35 # Subtelny podgląd na desktopie


func _draw() -> void:
	# Rysowanie pierścienia bazy
	var draw_center := _center_pos
	
	# 1. Zewnętrzny neonowy blask
	draw_circle(draw_center, max_radius + 8.0, _color_glow)
	
	# 2. Pierścień bazy
	draw_arc(draw_center, max_radius, 0.0, TAU, 48, _color_ring, 3.0, true)
	draw_circle(draw_center, 6.0, Color(1, 1, 1, 0.4))
	
	# 3. Gałka joysticka (Knob)
	var knob_pos := _current_pos
	# Cień/blask gałki
	draw_circle(knob_pos, 28.0, Color(0.0, 0.83, 1.0, 0.3))
	# Wewnętrzny okrąg gałki
	draw_circle(knob_pos, 22.0, _color_knob)
	draw_circle(knob_pos, 9.0, Color(1.0, 1.0, 1.0, 0.9))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_is_active = true
			# Jeśli kliknięto w obszarze kontrolki, przesuwamy bazę pod palec (Floating)
			_center_pos = event.position
			_update_position(event.position)
		elif not event.pressed and event.index == _touch_index:
			_reset_joystick()
			
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_position(event.position)


func _update_position(touch_pos: Vector2) -> void:
	var diff := touch_pos - _center_pos
	var dist := diff.length()
	
	if dist > max_radius:
		_current_pos = _center_pos + diff.normalized() * max_radius
	else:
		_current_pos = touch_pos
		
	if dist > deadzone:
		_output_vector = (diff / max_radius).limit_length(1.0)
	else:
		_output_vector = Vector2.ZERO
		
	_apply_input_actions(_output_vector)
	queue_redraw()


func _reset_joystick() -> void:
	_touch_index = -1
	_is_active = false
	_output_vector = Vector2.ZERO
	_center_pos = _default_center
	_current_pos = _default_center
	_apply_input_actions(Vector2.ZERO)
	queue_redraw()


func _apply_input_actions(vec: Vector2) -> void:
	# Symulacja akcji wejścia Godota (ui_left, ui_right, ui_up, ui_down)
	_set_action_strength("ui_right", maxf(0.0, vec.x))
	_set_action_strength("ui_left", maxf(0.0, -vec.x))
	_set_action_strength("ui_down", maxf(0.0, vec.y))
	_set_action_strength("ui_up", maxf(0.0, -vec.y))


func _set_action_strength(action: StringName, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		if Input.is_action_pressed(action):
			Input.action_release(action)
