class_name CraftingStation
extends Node2D
## A fixed crafting spot with a single recipe: interact with `input_item` in the
## inventory to turn it into `output_item` after `craft_time_sec`. The result
## pops out as a Pickup. Each kind of station is its own scene with different
## exports (the cooking spit is the first).
##
## Sounds: `start_sound` when crafting begins, `loop_sound` (positional loop)
## while it runs, `done_sound` when it finishes. Any can be left empty.

signal crafted(item: StringName)

@export var input_item: StringName = &"meat"
@export var output_item: StringName = &"cooked_meat"
@export var craft_time_sec := 4.0
## Optional node with an `is_lit` property (a campfire). Crafting only starts while it's lit.
@export var heat_source: Node
@export_group("Messages")
@export var missing_input_message := "Nothing to craft"
@export var needs_heat_message := "The fire is out"
@export var busy_message := "Already working"
@export_group("Audio")
@export var start_sound: StringName = &""
@export var loop_sound: StringName = &""
@export var done_sound: StringName = &""

var is_crafting := false
## 0..1 while crafting.
var progress := 0.0

var _elapsed := 0.0
var _loop: Node


func _process(delta: float) -> void:
	if not is_crafting:
		return
	_elapsed += delta
	progress = clampf(_elapsed / craft_time_sec, 0.0, 1.0)
	queue_redraw()
	if _elapsed >= craft_time_sec:
		_finish()


func interact(_player: Player) -> void:
	if is_crafting:
		GameState.notify(busy_message)
		return
	if heat_source and not heat_source.is_lit:
		GameState.notify(needs_heat_message)
		return
	if not GameState.spend(input_item):
		GameState.notify(missing_input_message)
		return
	is_crafting = true
	_elapsed = 0.0
	progress = 0.0
	if not start_sound.is_empty():
		AudioManager.play_at(start_sound, global_position)
	if not loop_sound.is_empty():
		_loop = AudioManager.play_loop(loop_sound, self, 0.3)
	queue_redraw()


func _exit_tree() -> void:
	AudioManager.stop_loop(_loop, 0.1)


func _finish() -> void:
	is_crafting = false
	progress = 0.0
	AudioManager.stop_loop(_loop, 0.3)
	_loop = null
	if not done_sound.is_empty():
		AudioManager.play_at(done_sound, global_position)
	Pickup.spawn(get_parent(), output_item, position)
	crafted.emit(output_item)
	queue_redraw()
