class_name CraftingStation
extends Node2D
## A fixed crafting spot. Its recipes are data (see Recipe). With a single recipe,
## interacting crafts it straight away (the cooking spit); with several, it asks the
## HUD for the crafting screen (GameState.craft_menu_requested) and the player picks.
## With `sequential`, the recipes are build stages done in order: interacting starts
## the next one, and the station is complete after the last (the shelter).
## Each kind of station is its own scene with different exports.
##
## Sounds: `start_sound` when crafting begins, `loop_sound` (positional loop)
## while it runs – or the recipe's own phases, if it has any – and `done_sound`
## when it finishes (`complete_sound` instead after a sequential station's last
## stage). Any can be left empty.

signal crafted(item: StringName)
## Sequential stations: emitted after each stage, with how many are now done.
signal stage_completed(stages_done: int)
signal completed

@export var station_name := "Crafting station"
## Button label on the crafting screen, e.g. "Grind".
@export var verb := "Craft"
@export var recipes: Array[Recipe] = []
## True: recipes are stages built in order, each started with the interact key.
@export var sequential := false
## Optional node with an `is_lit` property (a campfire). Crafting only starts while it's lit.
@export var heat_source: Node
## True: the result goes straight into the inventory. False: it pops out as a Pickup.
@export var output_to_inventory := false
@export_group("Messages")
## Shown when a single-recipe station is missing its inputs.
@export var missing_input_message := "Nothing to craft"
@export var needs_heat_message := "The fire is out"
@export var busy_message := "Already working"
## Sequential stations: shown when interacting after the last stage.
@export var complete_message := "Finished"
@export_group("Audio")
@export var start_sound: StringName = &""
@export var loop_sound: StringName = &""
@export var done_sound: StringName = &""
@export var complete_sound: StringName = &""

var is_crafting := false
## 0..1 while crafting.
var progress := 0.0
## The recipe in progress.
var current: Recipe
## Sequential stations: stages finished so far.
var stages_done := 0
var is_complete: bool:
	get:
		return sequential and stages_done >= recipes.size()

var _elapsed := 0.0
var _loop: Node
var _phase_index := -1
var _repeat_timer := 0.0


func _process(delta: float) -> void:
	if not is_crafting:
		return
	_elapsed += delta
	var total := current.total_time()
	progress = clampf(_elapsed / total, 0.0, 1.0)
	_update_phase(delta)
	queue_redraw()
	if _elapsed >= total:
		_finish()


func interact(_player: Player) -> void:
	if is_crafting:
		GameState.notify(busy_message)
		return
	if is_complete:
		GameState.notify(complete_message)
		return
	if not _has_heat():
		GameState.notify(needs_heat_message)
		return
	if sequential:
		var stage := recipes[stages_done]
		if not start(stage):
			GameState.notify("Needs %s" % stage.describe_inputs())
	elif recipes.size() == 1:
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
	_phase_index = -1
	if not start_sound.is_empty():
		AudioManager.play_at(start_sound, global_position)
	if not recipe.title.is_empty():
		GameState.notify("Building %s" % recipe.title)
	if recipe.phases.is_empty():
		if not loop_sound.is_empty():
			_loop = AudioManager.play_loop(loop_sound, self, 0.3)
	else:
		_update_phase(0.0)
	queue_redraw()
	return true


func _exit_tree() -> void:
	AudioManager.stop_loop(_loop, 0.1)


func _has_heat() -> bool:
	return heat_source == null or heat_source.is_lit


## Switches to the phase that `_elapsed` falls in, and fires repeated one-shots.
func _update_phase(delta: float) -> void:
	if current.phases.is_empty():
		return
	var index := 0
	var phase_end := current.phases[0].duration_sec
	while _elapsed >= phase_end and index < current.phases.size() - 1:
		index += 1
		phase_end += current.phases[index].duration_sec
	var phase := current.phases[index]
	if index != _phase_index:
		_phase_index = index
		AudioManager.stop_loop(_loop, 0.1)
		_loop = null
		if phase.interval_sec > 0.0:
			_repeat_timer = 0.0
		else:
			_loop = AudioManager.play_loop(phase.sound, self, 0.1)
	if phase.interval_sec > 0.0:
		_repeat_timer -= delta
		if _repeat_timer <= 0.0:
			_repeat_timer += phase.interval_sec
			AudioManager.play_at(phase.sound, global_position)


func _finish() -> void:
	is_crafting = false
	progress = 0.0
	AudioManager.stop_loop(_loop, 0.3)
	_loop = null
	if sequential:
		stages_done += 1
	var sound := complete_sound if is_complete and not complete_sound.is_empty() else done_sound
	if not sound.is_empty():
		AudioManager.play_at(sound, global_position)
	if not current.output.is_empty():
		if output_to_inventory:
			GameState.add(current.output, current.output_count)
			GameState.notify("Made %s" % Items.display_name(current.output).to_lower())
		else:
			for i in current.output_count:
				Pickup.spawn(get_parent(), current.output, position)
		crafted.emit(current.output)
	if sequential:
		stage_completed.emit(stages_done)
		if is_complete:
			completed.emit()
	queue_redraw()
