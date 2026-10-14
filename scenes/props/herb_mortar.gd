extends CraftingStation
## Stone mortar and pestle: grinds raw herbs into usable remedies (pick one on the
## crafting screen). Only the placeholder drawing lives here; the behaviour is CraftingStation's.


func _draw() -> void:
	var stone := Color(0.52, 0.52, 0.55)
	# Squat stone bowl with a dark, herb-stained rim.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -6), Vector2(10, -6), Vector2(7, 4), Vector2(-7, 4),
	]), stone)
	draw_line(Vector2(-10, -6), Vector2(10, -6), stone.darkened(0.35), 2.0)
	if is_crafting:
		draw_line(Vector2(-7, -6), Vector2(7, -6), Color(0.35, 0.5, 0.25), 2.0)
	# Pestle: leans on the rim at rest, bobs in a grinding circle while working.
	var t := Time.get_ticks_msec() / 1000.0
	var head := Vector2(4, -8)
	if is_crafting:
		head = Vector2(cos(t * 9.0) * 4.0, -7 + sin(t * 9.0) * 1.5)
	draw_line(head, head + Vector2(5, -12), stone.lightened(0.2), 3.0)
