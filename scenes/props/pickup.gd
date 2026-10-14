class_name Pickup
extends Area2D
## Item on the ground. Plays "pickup_<kind>" and adds itself to GameState when touched.

const SCENE_PATH := "res://scenes/props/pickup.tscn"
## Pickups can't be collected until they finish popping out, so the sound lands on its own.
const ARM_DELAY_SEC := 0.35

@export var kind: StringName = &"wood"


## Drops a pickup that pops out from `at`. Safe to call from physics callbacks.
static func spawn(parent: Node, item_kind: StringName, at: Vector2) -> void:
	var pickup := (load(SCENE_PATH) as PackedScene).instantiate() as Pickup
	pickup.kind = item_kind
	pickup.position = at
	parent.add_child.call_deferred(pickup)


func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	var landing := position + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 24.0)
	var tween := create_tween()
	tween.tween_property(self, "position", landing, ARM_DELAY_SEC) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(set_deferred.bind(&"monitoring", true))


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not body.is_dead:
		GameState.add(kind)
		AudioManager.play(StringName("pickup_%s" % kind))
		queue_free()


func _draw() -> void:
	match kind:
		&"wood":
			draw_rect(Rect2(-7, -3, 14, 6), Color(0.55, 0.36, 0.18))
			draw_circle(Vector2(7, 0), 3.0, Color(0.78, 0.62, 0.4))
		&"meat":
			draw_circle(Vector2.ZERO, 5.0, Color(0.75, 0.25, 0.25))
			draw_line(Vector2(3, -3), Vector2(8, -8), Color(0.95, 0.93, 0.88), 2.0)
		&"cooked_meat":
			draw_circle(Vector2.ZERO, 5.0, Color(0.52, 0.3, 0.14))
			draw_line(Vector2(3, -3), Vector2(8, -8), Color(0.95, 0.93, 0.88), 2.0)
		_:
			draw_circle(Vector2.ZERO, 5.0, Color.MAGENTA)
