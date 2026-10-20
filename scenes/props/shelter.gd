extends CraftingStation
## Lean-to shelter built in three stages at a fixed plot (frame, beams, roof; 2 wood
## each). Once finished, standing underneath slows hunger (see Player.is_sheltered).

@onready var _cover: Area2D = $Cover


func _ready() -> void:
	_cover.body_entered.connect(_on_cover_changed.bind(true))
	_cover.body_exited.connect(_on_cover_changed.bind(false))
	completed.connect(_on_completed)


func _on_completed() -> void:
	GameState.notify("Shelter built – rest under it to stay fed longer")
	for body in _cover.get_overlapping_bodies():
		_on_cover_changed(body, true)


func _on_cover_changed(body: Node2D, entered: bool) -> void:
	if body is Player and is_complete:
		body.is_sheltered = entered


func _draw() -> void:
	# Completed stages are solid; the one being built fades in as it progresses.
	_draw_plot()
	for stage in recipes.size():
		var alpha := 1.0 if stage < stages_done else 0.0
		if is_crafting and stage == stages_done:
			alpha = 0.25 + 0.75 * progress
		if alpha > 0.0:
			_draw_stage(stage, alpha)


func _draw_plot() -> void:
	# Marker stakes and a string outline on the ground.
	var string := Color(0.8, 0.72, 0.52, 0.6)
	var corners := PackedVector2Array([Vector2(-22, 0), Vector2(22, 0), Vector2(22, -14), Vector2(-22, -14)])
	for i in corners.size():
		draw_line(corners[i], corners[(i + 1) % corners.size()], string, 1.0)
		draw_line(corners[i], corners[i] + Vector2(0, -4), Color(0.45, 0.3, 0.15), 2.0)


func _draw_stage(stage: int, alpha: float) -> void:
	var wood := Color(0.45, 0.3, 0.15, alpha)
	match stage:
		0:  # Frame: tall front posts, short back posts.
			for x in [-20.0, 20.0]:
				draw_line(Vector2(x, 0), Vector2(x, -30), wood, 3.0)
				draw_line(Vector2(x, -14), Vector2(x, -22), wood.darkened(0.2), 2.5)
		1:  # Beams: front crossbeam and rafters sloping to the back posts.
			draw_line(Vector2(-23, -30), Vector2(23, -30), wood.lightened(0.1), 2.5)
			for x in [-20.0, 0.0, 20.0]:
				draw_line(Vector2(x, -30), Vector2(x, -22), wood.lightened(0.05), 2.0)
			draw_line(Vector2(-24, -24), Vector2(-16, -28), Color(0.8, 0.72, 0.52, alpha), 1.0)
			draw_line(Vector2(16, -28), Vector2(24, -24), Color(0.8, 0.72, 0.52, alpha), 1.0)
		2:  # Roof: layered pine boughs over the rafters.
			var bough := Color(0.15, 0.32, 0.2, alpha)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-25, -31), Vector2(25, -31), Vector2(25, -21), Vector2(-25, -21),
			]), bough)
			for i in 6:
				var x := -22.0 + i * 8.8
				draw_line(Vector2(x, -31), Vector2(x + 3, -21), bough.lightened(0.2), 1.0)
			draw_line(Vector2(-25, -31), Vector2(25, -31), Color(0.9, 0.93, 0.96, alpha * 0.8), 1.5)
