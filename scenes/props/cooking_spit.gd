extends CraftingStation
## Cooking spit beside the campfire: raw meat → cooked meat while the fire is lit.
## Only the placeholder drawing lives here; the behaviour is CraftingStation's.


func _draw() -> void:
	var wood := Color(0.42, 0.28, 0.14)
	# Forked posts and the spit bar.
	for x in [-12.0, 12.0]:
		draw_line(Vector2(x, 2), Vector2(x, -14), wood, 2.0)
		draw_line(Vector2(x, -14), Vector2(x - 3, -18), wood, 1.5)
		draw_line(Vector2(x, -14), Vector2(x + 3, -18), wood, 1.5)
	draw_line(Vector2(-16, -15), Vector2(16, -15), wood.lightened(0.15), 1.5)
	if not is_crafting:
		return
	# Meat browns as it cooks, with a wisp of smoke.
	var meat := Color(0.78, 0.26, 0.26).lerp(Color(0.5, 0.3, 0.14), progress)
	draw_circle(Vector2(0, -15), 5.0, meat)
	var t := Time.get_ticks_msec() / 1000.0
	for i in 3:
		var rise := fmod(t * 0.8 + i / 3.0, 1.0)
		draw_circle(Vector2(sin(t * 3.0 + i) * 2.0, -22 - rise * 12.0), 1.5 + rise * 1.5,
				Color(0.85, 0.85, 0.85, 0.5 * (1.0 - rise)))
