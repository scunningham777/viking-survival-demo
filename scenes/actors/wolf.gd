extends CharacterBody2D
## Wolf that hunts the player and drops meat when killed.
## Placeholder visuals are drawn in _draw().

@export var move_speed := 95.0
@export var max_health := 50.0
@export var bite_damage := 12.0
@export var bite_range := 24.0
@export var bite_cooldown_sec := 1.1
## Random seconds between growls (min, max).
@export var growl_interval_sec := Vector2(3.0, 7.0)

var health: float

var _target: Player
var _facing := Vector2.LEFT
var _bite_cooldown := 0.0
var _growl_timer := 0.0
var _knockback := Vector2.ZERO
var _hurt_flash := 0.0


func _ready() -> void:
	health = max_health
	_growl_timer = randf_range(growl_interval_sec.x, growl_interval_sec.y)
	_target = get_tree().get_first_node_in_group(&"player") as Player
	AudioManager.play_at(&"wolf_howl", global_position)


func _physics_process(delta: float) -> void:
	_bite_cooldown = maxf(_bite_cooldown - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_growl_timer = randf_range(growl_interval_sec.x, growl_interval_sec.y)
		AudioManager.play_at(&"wolf_growl", global_position)

	var chase := Vector2.ZERO
	if is_instance_valid(_target) and not _target.is_dead:
		var to_target := _target.global_position - global_position
		_facing = to_target.normalized()
		if to_target.length() > bite_range:
			chase = _facing * move_speed
		elif _bite_cooldown <= 0.0:
			_bite()
	velocity = chase + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	queue_redraw()


func take_hit(amount: float, source: Node2D) -> void:
	health -= amount
	_hurt_flash = 1.0
	_knockback = source.global_position.direction_to(global_position) * 280.0
	if health <= 0.0:
		_die()
	else:
		AudioManager.play_at(&"wolf_hurt", global_position)


func _bite() -> void:
	_bite_cooldown = bite_cooldown_sec
	AudioManager.play_at(&"wolf_bite", global_position)
	_target.take_hit(bite_damage, self)


func _die() -> void:
	AudioManager.play_at(&"wolf_death", global_position)
	Pickup.spawn(get_parent(), &"meat", position)
	queue_free()


func _draw() -> void:
	var color := Color(0.52, 0.53, 0.58).lerp(Color(1.0, 0.3, 0.3), _hurt_flash)
	var side := _facing.orthogonal()
	draw_circle(-_facing * 4.0, 9.0, color)
	var head := _facing * 9.0
	draw_circle(head, 6.5, color)
	draw_line(-_facing * 12.0, -_facing * 20.0 + side * 3.0, color, 3.0)  # tail
	draw_circle(head + _facing * 2.5 + side * 2.5, 1.3, Color(1.0, 0.85, 0.2))
	draw_circle(head + _facing * 2.5 - side * 2.5, 1.3, Color(1.0, 0.85, 0.2))
