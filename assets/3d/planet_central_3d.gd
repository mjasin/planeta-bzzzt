class_name PlanetCentral3D
extends Node3D

## PlanetCentral3D - Centralna Mecha-Planeta Bzzzt w pełnym 3D
## Wyposażona w obracające się pierścienie orbitalne, pulsujący rdzeń energetyczny i neonowe oświetlenie

@export_group("Rotacja i Animacja")
@export var planet_rotation_speed: float = 0.3
@export var ring_rotation_speed: float = 0.6
@export var pulse_speed: float = 2.5

@onready var planet_body: MeshInstance3D = $PlanetBody
@onready var ring_a: Node3D = $Rings/RingA
@onready var ring_b: Node3D = $Rings/RingB
@onready var core_light: OmniLight3D = $CoreLight

var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	
	# Powolny obrót korpusu planety
	if planet_body:
		planet_body.rotate_y(planet_rotation_speed * delta)
		
	# Przeciwstawny obrót pierścieni orbitalnych
	if ring_a:
		ring_a.rotate_y(ring_rotation_speed * delta)
	if ring_b:
		ring_b.rotate_x(-ring_rotation_speed * 0.7 * delta)
		
	# Pulsowanie światła rdzenia planety
	if core_light:
		var pulse := (sin(_time * pulse_speed) + 1.0) * 0.5
		core_light.light_energy = 2.0 + pulse * 1.5
