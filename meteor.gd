class_name Meteor
extends UFO

## Meteor - Klasa zachowana dla kompatybilności wstecznej (dziedziczy po UFO).

# --- ZMIENNE EKSPORTOWANE ---
@export var rotation_speed: float = 1.2 ## Prędkość obrotu meteoru
@export var follow_speed: float = 120.0 ## Prędkość podążania za graczem
@export var is_chasing_player: bool = false ## Czy meteor śledzi gracza?

# --- REFERENCJE DO WĘZŁÓW ---
@onready var sprite: Sprite2D = $Sprite2D

# --- ZMIENNE PRYWATNE ---
var target_player: CharacterBody2D = null
var _anim_time: float = 0.0
var is_frozen: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if is_frozen:
		return
	_anim_time += delta * 3.0
	
	# Obrót wokół własnej osi
	rotation += rotation_speed * delta
	
	# Mroczna, purpurowa poświata z pulsowaniem krawędzi
	_apply_purple_neon_glow()
	
	if is_chasing_player and target_player != null:
		_chase_player(delta)


## Ustawia i pulsuje neonową purpurę (HDR Magenta Glow)
func _apply_purple_neon_glow() -> void:
	if sprite:
		var glow_pulse: float = (sin(_anim_time * 2.5) + 1.0) * 0.5
		var glow_color := Color(1.2 + glow_pulse * 0.3, 0.9, 1.4 + glow_pulse * 0.4, 1.0)
		sprite.modulate = glow_color


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		print("💥 BZZZT! Meteor uderzył w gracza!")
		if body is CharacterBody2D:
			target_player = body
		
		_on_player_hit(body)


func _on_player_hit(player_node: Node2D) -> void:
	# Gracz wybucha po wpadnięciu w meteor!
	if player_node.has_method("explode"):
		player_node.call("explode")
	
	# Wstrząs przeszkody
	var tween := create_tween().set_trans(Tween.TRANS_SPRING)
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)


func _chase_player(delta: float) -> void:
	if target_player != null:
		var direction: Vector2 = (target_player.global_position - global_position).normalized()
		global_position += direction * follow_speed * delta


# ==============================================================================
# METODY DLA PROMPTÓW NA ŻYWO (VIBE CODING)
# ==============================================================================

func start_chasing(player_ref: CharacterBody2D) -> void:
	target_player = player_ref
	is_chasing_player = true
	print("☄️ Purpurowy Meteor zaczął śledzić gracza!")


## Zatrzymuje pościg za graczem
func stop_chasing() -> void:
	is_chasing_player = false
	target_player = null
	print("🛑 Meteor przestał gonić gracza.")


func spin_crazy(extra_speed: float = 8.0) -> void:
	rotation_speed += extra_speed


## Zatrzymuje meteor w miejscu (np. po ukończeniu poziomu)
func freeze() -> void:
	is_frozen = true
	stop_chasing()


## Wznawia działanie meteoru
func unfreeze() -> void:
	is_frozen = false


## Modyfikuje prędkość poruszania się i obrotu meteoru (np. o 10% na każdy kolejny poziom)
func apply_speed_multiplier(multiplier: float) -> void:
	follow_speed *= multiplier
	rotation_speed *= multiplier
	print("☄️ Nowa prędkość meteoru: %.1f (mnożnik: x%.2f)" % [follow_speed, multiplier])
