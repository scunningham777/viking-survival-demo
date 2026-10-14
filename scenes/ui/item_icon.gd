class_name ItemIcon
extends Control
## Placeholder icon for an inventory item, drawn to fit the control.
## Replace _draw() with a TextureRect lookup once item sprites exist.

@export var item: StringName = &"":
	set(value):
		item = value
		queue_redraw()


func _draw() -> void:
	if item.is_empty():
		return
	# Icons are authored in a 24×24 box centred on the origin.
	var s := minf(size.x, size.y) / 24.0
	draw_set_transform(size / 2.0, 0.0, Vector2(s, s))
	var stem := Color(0.32, 0.5, 0.25)
	match item:
		&"wood":
			for y in [-4.0, 4.0]:
				draw_rect(Rect2(-9, y - 3, 16, 6), Color(0.55, 0.36, 0.18))
				draw_circle(Vector2(7, y), 3.0, Color(0.78, 0.62, 0.4))
		&"meat":
			draw_line(Vector2(3, -3), Vector2(9, -9), Color(0.95, 0.93, 0.88), 2.5)
			draw_circle(Vector2(9, -9), 2.0, Color(0.95, 0.93, 0.88))
			draw_circle(Vector2(-1, 1), 7.0, Color(0.75, 0.25, 0.25))
			draw_circle(Vector2(-3, 0), 2.5, Color(0.92, 0.75, 0.7))
		&"cooked_meat":
			draw_line(Vector2(3, -3), Vector2(9, -9), Color(0.95, 0.93, 0.88), 2.5)
			draw_circle(Vector2(9, -9), 2.0, Color(0.95, 0.93, 0.88))
			draw_circle(Vector2(-1, 1), 7.0, Color(0.52, 0.3, 0.14))
			draw_line(Vector2(-6, -1), Vector2(3, 4), Color(0.32, 0.17, 0.07), 1.5)
			draw_line(Vector2(-5, 3), Vector2(2, 7), Color(0.32, 0.17, 0.07), 1.5)
		&"yarrow":
			for x in [-5.0, 0.0, 5.0]:
				draw_line(Vector2(x * 0.4, 10), Vector2(x, -4 - absf(x) * 0.5), stem, 1.5)
				for i in 3:
					draw_circle(Vector2(x + i * 2.0 - 2.0, -5 - absf(x) * 0.5), 1.8, Color(0.96, 0.95, 0.88))
		&"angelica":
			draw_line(Vector2(0, 10), Vector2(0, -4), stem.lightened(0.1), 2.5)
			draw_line(Vector2(0, 4), Vector2(-5, 0), stem, 1.5)
			for i in 5:
				var tip := Vector2(0, -4) + Vector2.from_angle(PI + PI * i / 4.0) * 6.0
				draw_line(Vector2(0, -4), tip, stem, 1.0)
				draw_circle(tip, 1.8, Color(0.8, 0.9, 0.62))
		&"wolfsbane":
			draw_line(Vector2(0, 10), Vector2(0, -8), stem.darkened(0.2), 1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(-7, 9), Vector2(0, 4), Vector2(-2, 10)]), stem)
			draw_colored_polygon(PackedVector2Array([Vector2(7, 9), Vector2(0, 4), Vector2(2, 10)]), stem)
			for i in 4:
				draw_circle(Vector2(0, -8 + i * 3.5), 3.0 - i * 0.3, Color(0.48, 0.28, 0.78))
		_:
			draw_circle(Vector2.ZERO, 6.0, Color.MAGENTA)
