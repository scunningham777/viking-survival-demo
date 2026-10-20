class_name Player
extends CharacterBody2D
## Top-down viking. WASD / arrows / left stick to move, Space or click to swing
## the axe, E to feed the campfire / harvest herbs, F to eat meat, 1–3 to use herb remedies.
## Placeholder visuals are drawn in _draw(); swap in a Sprite2D/AnimatedSprite2D later.

signal health_changed(current: float, maximum: float)
signal hunger_changed(current: float, maximum: float)
signal died

## Herb remedies in hotkey order (1, 2, 3) → the sound played when used.
const REMEDIES: Dictionary[StringName, StringName] = {
	&"yarrow_poultice": &"herb_yarrow_use",
	&"angelica_mash": &"herb_angelica_use",
	&"wolfsbane_paste": &"herb_wolfsbane_use",
}

@export var move_speed := 140.0
@export var max_health := 100.0
@export var max_hunger := 100.0
@export var hunger_drain_per_sec := 1.2
## Hunger drain is multiplied by this while standing under a finished shelter.
@export var shelter_hunger_multiplier := 0.5
@export var starving_damage_per_sec := 4.0
@export var meat_hunger_restore := 35.0
## Cooked meat (from the cooking spit) is eaten before raw meat.
@export var cooked_meat_hunger_restore := 60.0
@export_group("Herb remedies")
@export var yarrow_heal := 30.0
@export var angelica_hunger_restore := 20.0
@export var wolfsbane_duration_sec := 20.0
@export var wolfsbane_damage_multiplier := 2.0
@export_group("Combat")
@export var attack_damage := 25.0
@export var attack_range := 34.0
## Physics layers the axe can hit (1 = world/trees, 3 = enemies).
@export_flags_2d_physics var attack_mask := 5
@export var attack_cooldown_sec := 0.45
## Delay between the swing whoosh and the impact, so both sounds read clearly.
@export var attack_impact_delay_sec := 0.08
## Swing width: 1 = straight ahead only, 0 = 180°, -1 = all around.
@export_range(-1.0, 1.0) var attack_arc_dot := 0.2
@export_group("Audio")
## Distance walked between footstep sounds.
@export var footstep_distance := 34.0

var health: float
var hunger: float
var facing := Vector2.DOWN
var is_dead := false
## Seconds left on the wolfsbane-poisoned axe.
var wolfsbane_time := 0.0
## Set by a finished shelter while the player stands under it.
var is_sheltered := false

var _attack_cooldown := 0.0
var _swing_visual := 0.0
var _hurt_flash := 0.0
var _step_distance := 0.0

@onready var _interact_area: Area2D = $InteractArea


func _ready() -> void:
	health = max_health
	hunger = max_hunger


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_swing_visual = maxf(_swing_visual - delta * 5.0, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	_update_wolfsbane(delta)
	queue_redraw()
	if is_dead:
		return

	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = input * move_speed
	if input != Vector2.ZERO:
		facing = input.normalized()
	var before := global_position
	move_and_slide()
	_update_footsteps(global_position.distance_to(before))
	_update_hunger(delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event.is_action_pressed(&"attack"):
		if event is InputEventMouseButton:
			facing = global_position.direction_to(get_global_mouse_position())
		_attack()
	elif event.is_action_pressed(&"interact"):
		_interact()
	elif event.is_action_pressed(&"eat"):
		_eat()
	else:
		for i in REMEDIES.size():
			if event.is_action_pressed(StringName("use_herb_%d" % (i + 1))):
				use_remedy(REMEDIES.keys()[i])
				return


func take_hit(amount: float, _source: Node2D) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	_hurt_flash = 1.0
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()
	else:
		AudioManager.play(&"player_hurt")


func heal(amount: float) -> void:
	if is_dead or health >= max_health:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


func _update_footsteps(moved: float) -> void:
	_step_distance += moved
	if _step_distance >= footstep_distance:
		_step_distance = 0.0
		AudioManager.play(&"footstep")


func hunger_drain() -> float:
	return hunger_drain_per_sec * (shelter_hunger_multiplier if is_sheltered else 1.0)


func _update_hunger(delta: float) -> void:
	hunger = maxf(hunger - hunger_drain() * delta, 0.0)
	hunger_changed.emit(hunger, max_hunger)
	if hunger <= 0.0:
		health = maxf(health - starving_damage_per_sec * delta, 0.0)
		health_changed.emit(health, max_health)
		if health <= 0.0:
			_die()


func _attack() -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = attack_cooldown_sec
	_swing_visual = 1.0
	AudioManager.play(&"axe_swing")
	await get_tree().create_timer(attack_impact_delay_sec).timeout
	if is_dead:
		return
	var damage := attack_damage * (wolfsbane_damage_multiplier if wolfsbane_time > 0.0 else 1.0)
	for body in _bodies_in_attack_range():
		if body.has_method(&"take_hit") \
				and facing.dot(global_position.direction_to(body.global_position)) >= attack_arc_dot:
			body.take_hit(damage, self)


func _bodies_in_attack_range() -> Array[Node2D]:
	var shape := CircleShape2D.new()
	shape.radius = attack_range
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = attack_mask
	query.exclude = [get_rid()]
	var bodies: Array[Node2D] = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		if hit.collider is Node2D and hit.collider not in bodies:
			bodies.append(hit.collider)
	return bodies


## Interacts with the nearest interactable in reach (the campfire and spit sit side by side).
func _interact() -> void:
	var nearest: Node2D
	for area in _interact_area.get_overlapping_areas():
		var target := area.get_parent()
		if target.has_method(&"interact") and (nearest == null
				or global_position.distance_to(area.global_position)
				< global_position.distance_to(nearest.global_position)):
			nearest = area
	if nearest:
		nearest.get_parent().interact(self)


func _eat() -> void:
	if hunger >= max_hunger - 1.0:
		GameState.notify("Not hungry")
		return
	var restore := cooked_meat_hunger_restore
	if not GameState.spend(&"cooked_meat"):
		restore = meat_hunger_restore
		if not GameState.spend(&"meat"):
			GameState.notify("No meat – hunt wolves")
			return
	hunger = minf(hunger + restore, max_hunger)
	hunger_changed.emit(hunger, max_hunger)
	AudioManager.play(&"eat")


## Uses one herb remedy (made at the herb mortar). Returns false (with a HUD message) if it
## had no effect.
func use_remedy(item: StringName) -> bool:
	if is_dead or item not in REMEDIES:
		return false
	if GameState.count(item) <= 0:
		GameState.notify("No %s – grind herbs at the mortar" % Items.display_name(item).to_lower())
		return false
	match item:
		&"yarrow_poultice":
			if health >= max_health - 1.0:
				GameState.notify("Not wounded")
				return false
			heal(yarrow_heal)
		&"angelica_mash":
			if hunger >= max_hunger - 1.0:
				GameState.notify("Not hungry")
				return false
			hunger = minf(hunger + angelica_hunger_restore, max_hunger)
			hunger_changed.emit(hunger, max_hunger)
		&"wolfsbane_paste":
			wolfsbane_time = wolfsbane_duration_sec
			GameState.notify("Axe poisoned with wolfsbane")
	GameState.spend(item)
	AudioManager.play(REMEDIES[item])
	return true


func _update_wolfsbane(delta: float) -> void:
	if wolfsbane_time <= 0.0:
		return
	wolfsbane_time = maxf(wolfsbane_time - delta, 0.0)
	if wolfsbane_time == 0.0 and not is_dead:
		AudioManager.play(&"herb_wolfsbane_wear_off")
		GameState.notify("The wolfsbane has worn off")


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	AudioManager.play(&"player_death")
	died.emit()


func _draw() -> void:
	var body_color := Color(0.78, 0.58, 0.38).lerp(Color(1.0, 0.25, 0.25), _hurt_flash)
	if is_dead:
		body_color = Color(0.4, 0.4, 0.4)
	draw_circle(Vector2.ZERO, 10.0, body_color)
	# Helmet and horns
	draw_circle(Vector2(0, -3), 7.0, Color(0.6, 0.62, 0.66))
	draw_line(Vector2(-6, -6), Vector2(-12, -15), Color(0.95, 0.92, 0.82), 2.5)
	draw_line(Vector2(6, -6), Vector2(12, -15), Color(0.95, 0.92, 0.82), 2.5)
	if is_dead:
		return
	# Axe sweeps through an arc while swinging
	var angle := facing.angle()
	if _swing_visual > 0.0:
		angle += lerpf(1.3, -1.3, _swing_visual)
	var tip := Vector2.from_angle(angle) * 22.0
	draw_line(Vector2.ZERO, tip, Color(0.45, 0.3, 0.15), 3.0)
	var blade := Color(0.82, 0.84, 0.88)
	if wolfsbane_time > 0.0:
		blade = blade.lerp(Color(0.55, 0.3, 0.85), 0.7)
	draw_circle(tip, 4.0, blade)
