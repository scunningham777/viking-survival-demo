class_name HerbPlant
extends Node2D
## Wild herb. Harvest it with the interact key; it regrows after a while.
## Plays "herb_<kind>_pick" when harvested. The player uses herbs (see Player.use_herb()).

## Every herb variety, in hotkey order (1, 2, 3).
const KINDS: Array[StringName] = [&"yarrow", &"angelica", &"wolfsbane"]

@export var kind: StringName = &"yarrow"
@export var regrow_sec := 75.0

var is_grown := true

var _regrow_timer := 0.0
var _sway_time := 0.0

@onready var _interact_zone: Area2D = $InteractZone


func _ready() -> void:
	_sway_time = randf() * TAU


func _process(delta: float) -> void:
	_sway_time += delta
	if not is_grown:
		_regrow_timer -= delta
		if _regrow_timer <= 0.0:
			_set_grown(true)
	queue_redraw()


func interact(_player: Player) -> void:
	if not is_grown:
		GameState.notify("Not ready – it will grow back")
		return
	GameState.add(kind)
	AudioManager.play_at(StringName("herb_%s_pick" % kind), global_position)
	GameState.notify("Picked %s" % Items.display_name(kind))
	_regrow_timer = regrow_sec
	_set_grown(false)


func _set_grown(grown: bool) -> void:
	is_grown = grown
	# Picked plants stop catching the interact key, so a ripe neighbour gets it instead.
	_interact_zone.set_deferred(&"monitorable", grown)


func _draw() -> void:
	var sway := sin(_sway_time * 1.7) * 1.2
	var stem := Color(0.28, 0.45, 0.22)
	if not is_grown:
		for x in [-3.0, 0.0, 3.0]:
			draw_line(Vector2(x, 0), Vector2(x * 1.3, -4), stem.darkened(0.3), 1.5)
		return
	match kind:
		&"yarrow":
			# Feathery leaves and flat white flower clusters.
			for x in [-4.0, 0.0, 4.0]:
				var top := Vector2(x * 1.5 + sway, -12 - absf(x))
				draw_line(Vector2(x * 0.5, 0), top, stem, 1.5)
				for i in 3:
					draw_circle(top + Vector2(i * 2.0 - 2.0, 0), 1.8, Color(0.96, 0.95, 0.88))
		&"angelica":
			# Tall hollow stalk topped with a green-white umbel.
			draw_line(Vector2(0, 0), Vector2(sway, -20), stem.lightened(0.1), 2.5)
			draw_line(Vector2(0, -6), Vector2(-6, -10), stem, 1.5)
			draw_line(Vector2(0, -8), Vector2(6, -12), stem, 1.5)
			for i in 5:
				var tip := Vector2(sway, -20) + Vector2.from_angle(PI + PI * i / 4.0) * 5.0
				draw_line(Vector2(sway, -20), tip, stem, 1.0)
				draw_circle(tip, 1.6, Color(0.8, 0.9, 0.62))
		&"wolfsbane":
			# Dark leaves and a spike of purple hooded flowers.
			draw_line(Vector2(0, 0), Vector2(sway, -16), stem.darkened(0.2), 1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -1), Vector2(0, -5), Vector2(-2, 0)]), stem)
			draw_colored_polygon(PackedVector2Array([Vector2(6, -1), Vector2(0, -5), Vector2(2, 0)]), stem)
			for i in 4:
				draw_circle(Vector2(sway * (1.0 - i * 0.2), -16 + i * 3.0), 2.4 - i * 0.2, Color(0.42, 0.24, 0.7))
		_:
			draw_circle(Vector2(0, -6), 5.0, Color.MAGENTA)
