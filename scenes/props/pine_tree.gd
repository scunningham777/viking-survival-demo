extends StaticBody2D
## Choppable pine. Drops wood when felled.

@export var chops_to_fell := 4
@export var wood_dropped := 2

var _chops_left: int
var _shake := 0.0


func _ready() -> void:
	_chops_left = chops_to_fell


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 4.0, 0.0)
		queue_redraw()


func take_hit(_amount: float, _source: Node2D) -> void:
	_chops_left -= 1
	_shake = 1.0
	if _chops_left > 0:
		AudioManager.play_at(&"axe_hit_wood", global_position)
		return
	AudioManager.play_at(&"tree_fall", global_position)
	for i in wood_dropped:
		Pickup.spawn(get_parent(), &"wood", position)
	queue_free()


func _draw() -> void:
	var sway := Vector2(sin(_shake * 30.0) * 3.0 * _shake, 0.0)
	draw_rect(Rect2(-3, -10, 6, 12), Color(0.4, 0.26, 0.14))
	for tier in 3:
		var y := -10.0 - tier * 12.0
		var half := 16.0 - tier * 4.0
		draw_colored_polygon(PackedVector2Array([
			sway + Vector2(-half, y), sway + Vector2(half, y), sway + Vector2(0, y - 20.0),
		]), Color(0.13, 0.3, 0.2))
	draw_colored_polygon(PackedVector2Array([
		sway + Vector2(-4, -47), sway + Vector2(4, -47), sway + Vector2(0, -54),
	]), Color(0.92, 0.95, 0.98))
