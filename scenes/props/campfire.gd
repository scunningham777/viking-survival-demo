extends Node2D
## The camp's fire. Burns fuel over time, heals the player nearby, and is fed
## wood with the interact key. Its crackle is a positional loop.

@export var max_fuel_sec := 120.0
@export var start_fuel_sec := 60.0
@export var fuel_per_wood_sec := 30.0
@export var heal_per_sec := 4.0
@export var glow_energy := 1.3

var fuel: float
var is_lit := false

var _crackle: Node
var _time := 0.0

@onready var _warmth_zone: Area2D = $WarmthZone
@onready var _glow: PointLight2D = $Glow


func _ready() -> void:
	fuel = start_fuel_sec
	_set_lit(fuel > 0.0)


func _process(delta: float) -> void:
	_time += delta
	if is_lit:
		fuel -= delta
		if fuel <= 0.0:
			fuel = 0.0
			_set_lit(false)
			AudioManager.play_at(&"campfire_extinguish", global_position)
			GameState.notify("The fire has gone out")
		else:
			for body in _warmth_zone.get_overlapping_bodies():
				if body is Player:
					body.heal(heal_per_sec * delta)
	_glow.energy = glow_energy * (0.85 + 0.15 * sin(_time * 13.0) * sin(_time * 7.3))
	queue_redraw()


func interact(_player: Player) -> void:
	if fuel > max_fuel_sec - fuel_per_wood_sec * 0.5:
		GameState.notify("The fire is roaring")
		return
	if not GameState.spend(&"wood"):
		GameState.notify("No wood – chop some trees")
		return
	fuel = minf(fuel + fuel_per_wood_sec, max_fuel_sec)
	if is_lit:
		AudioManager.play_at(&"campfire_add_wood", global_position)
	else:
		AudioManager.play_at(&"campfire_ignite", global_position)
		_set_lit(true)


func _set_lit(lit: bool) -> void:
	is_lit = lit
	_glow.enabled = lit
	if lit and _crackle == null:
		_crackle = AudioManager.play_loop(&"campfire_loop", self)
	elif not lit and _crackle != null:
		AudioManager.stop_loop(_crackle, 1.0)
		_crackle = null


func _draw() -> void:
	for i in 7:
		draw_circle(Vector2.from_angle(TAU * i / 7.0) * Vector2(13, 8), 4.0, Color(0.45, 0.45, 0.48))
	draw_line(Vector2(-9, 3), Vector2(9, -3), Color(0.4, 0.25, 0.12), 4.0)
	draw_line(Vector2(-9, -3), Vector2(9, 3), Color(0.35, 0.22, 0.1), 4.0)
	if not is_lit:
		return
	var size := lerpf(0.6, 1.2, fuel / max_fuel_sec) * (1.0 + 0.12 * sin(_time * 18.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size, size))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(0, -22), Vector2(7, 0)]), Color(1.0, 0.5, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(0, -12), Vector2(4, 0)]), Color(1.0, 0.88, 0.35))
	draw_set_transform(Vector2.ZERO)
