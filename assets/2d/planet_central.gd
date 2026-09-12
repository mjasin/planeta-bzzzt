class_name PlanetCentral
extends Node2D

## PlanetCentral - Programowo rysowana okrągła Mecha-Planeta Bzzzt
## Posiada wbudowane koła zębate, pulsujący rdzeń i eliptyczny pierścień orbity!

# --- ZMIENNE EKSPORTOWANE ---
@export var rotation_speed: float = 0.15 ## Prędkość powolnego obrotu
@export var pulse_speed: float = 0.002 ## Prędkość oddychania

# --- ZMIENNE PRYWATNE ---
var _base_scale: Vector2 = Vector2.ONE
var _anim_time: float = 0.0

func _ready() -> void:
	_base_scale = scale
	_setup_orbital_particles()


func _process(delta: float) -> void:
	_anim_time += delta
	rotation += rotation_speed * delta
	
	# Płynne oddychanie i pulsowanie skali (0.98 - 1.02)
	var pulse: float = sin(Time.get_ticks_msec() * pulse_speed) * 0.025
	scale = _base_scale * (1.0 + pulse)
	queue_redraw()


func _draw() -> void:
	# 1. Zewnętrzna poświata aury (Neon Blue HDR Glow)
	draw_circle(Vector2.ZERO, 105.0, Color(0.2, 2.0, 3.5, 0.22))
	draw_circle(Vector2.ZERO, 92.0, Color(0.3, 2.5, 4.0, 0.35))
	
	# 2. Główny okrągły korpus mecha-planety
	var body_color := Color(0.06, 0.12, 0.28, 1.0)
	draw_circle(Vector2.ZERO, 80.0, body_color)
	
	# 3. Zewnętrzny cyfrowy obrys HDR
	var rim_color := Color(0.3, 2.8, 4.0, 1.0)
	draw_arc(Vector2.ZERO, 80.0, 0, TAU, 64, rim_color, 4.0)
	
	# 4. Zęby koła zębatego na krawędzi (Mecha Gears)
	var gear_teeth: int = 8
	for i in gear_teeth:
		var angle: float = (i * TAU / gear_teeth)
		var tooth_pos := Vector2(cos(angle), sin(angle)) * 82.0
		draw_circle(tooth_pos, 10.0, rim_color)
		draw_circle(tooth_pos, 5.0, body_color)
	
	# 5. Wewnętrzne okręgi i linie technologiczne
	draw_arc(Vector2.ZERO, 56.0, 0, TAU, 48, Color(0.2, 1.8, 3.0, 0.8), 2.5)
	draw_arc(Vector2.ZERO, 36.0, 0, TAU, 32, Color(0.4, 2.5, 4.0, 0.9), 2.0)
	
	# 6. Centralny świecący rdzeń (Cyfrowy Bzzzt Core)
	var core_pulse: float = (sin(_anim_time * 4.0) + 1.0) * 0.5
	var core_color := Color(0.3 + core_pulse * 0.4, 2.5 + core_pulse * 1.0, 4.0, 1.0)
	draw_circle(Vector2.ZERO, 18.0, core_color)
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 1.0, 1.0, 0.95)) # Biały błysk środka
	
	# 7. Pierścień eliptycznej orbity
	for i in 64:
		var a1: float = (i * TAU / 64.0)
		var a2: float = ((i + 0.5) * TAU / 64.0)
		var p1 := Vector2(cos(a1) * 160.0, sin(a1) * 75.0)
		var p2 := Vector2(cos(a2) * 160.0, sin(a2) * 75.0)
		draw_line(p1, p2, Color(0.3, 2.0, 3.5, 0.35), 2.0)


## Tworzy dodający klimatu pierścień krążących pyłków wokół planety
func _setup_orbital_particles() -> void:
	var ring_particles := CPUParticles2D.new()
	ring_particles.name = "RingParticles"
	ring_particles.amount = 45
	ring_particles.lifetime = 5.0
	ring_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	ring_particles.emission_ring_radius = 160.0
	ring_particles.emission_ring_inner_radius = 130.0
	ring_particles.gravity = Vector2(0, 0)
	ring_particles.orbit_velocity_min = 0.2
	ring_particles.orbit_velocity_max = 0.5
	ring_particles.scale_amount_min = 3.0
	ring_particles.scale_amount_max = 6.0
	ring_particles.color = Color(0.2, 2.5, 3.5, 0.7)
	
	add_child(ring_particles)
	ring_particles.emitting = true
