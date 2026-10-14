class_name CraftingStation
extends Node2D
## A fixed crafting spot. Its recipes are data (see Recipe). With a single recipe,
## interacting crafts it straight away (the cooking spit); with several, it asks the
## HUD for the crafting screen (GameState.craft_menu_requested) and the player picks.
## Each kind of station is its own scene with different exports.
##
## Sounds: `start_sound` when crafting begins, `loop_sound` (positional loop)
## while it runs, `done_sound` when it finishes. Any can be left empty.

signal crafted(item: StringName)

@export var station_name := "Crafting station"
## Button label on the crafting screen, e.g. "Grind".
@export var verb := "Craft"
@export var recipes: Array[Recipe] = []
## Optional node with an `is_lit` property (a campfire). Crafting only starts while it's lit.
@export var heat_source: Node
## True: the result goes straight into the inventory. False: it pops out as a Pickup.
@export var output_to_inventory := false
@export_group("Messages")
## Shown when a single-recipe station is missing its inputs.
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
## The recipe in progress.
var current: Recipe

var _elapsed := 0.0
var _loop: Node


func _process(delta: float) -> void:
	if not is_crafting:
		return
	_elapsed += delta
	progress = clampf(_elapsed / current.craft_time_sec, 0.0, 1.0)
	queue_redraw()
	if _elapsed >= current.craft_time_sec:
		_finish()


func interact(_player: Player) -> void:
	if is_crafting:
		GameState.notify(busy_message)
		return
	if not _has_heat():
		GameState.notify(needs_heat_message)
		return
	if recipes.size() == 1:
		if not start(recipes[0]):
			GameState.notify(missing_input_message)
	elif recipes.size() > 1:
		GameState.craft_menu_requested.emit(self)


## Starts crafting `recipe`, spending its inputs. Returns false if it can't.
func start(recipe: Recipe) -> bool:
	if is_crafting or not _has_heat() or not recipe.spend_inputs():
		return false
	current = recipe
	is_crafting = true
	_elapsed = 0.0
	progress = 0.0
	if not start_sound.is_empty():
		AudioManager.play_at(start_sound, global_position)
	if not loop_sound.is_empty():
		_loop = AudioManager.play_loop(loop_sound, self, 0.3)
	queue_redraw()
	return true


func _exit_tree() -> void:
	AudioManager.stop_loop(_loop, 0.1)


func _has_heat() -> bool:
	return heat_source == null or heat_source.is_lit


func _finish() -> void:
	is_crafting = false
	progress = 0.0
	AudioManager.stop_loop(_loop, 0.3)
	_loop = null
	if not done_sound.is_empty():
		AudioManager.play_at(done_sound, global_position)
	if output_to_inventory:
		GameState.add(current.output, current.output_count)
		GameState.notify("Made %s" % Items.display_name(current.output).to_lower())
	else:
		for i in current.output_count:
			Pickup.spawn(get_parent(), current.output, position)
	crafted.emit(current.output)
	queue_redraw()
