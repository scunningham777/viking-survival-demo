class_name Recipe
extends Resource
## One crafting recipe: consumes `inputs` from the inventory and produces
## `output_count` × `output` after `craft_time_sec`. Stations hold a list of these.
## A recipe with no `output` produces nothing (a build stage). With `phases`, the
## craft plays that sound sequence and lasts as long as the phases combined.

## Short name for messages, e.g. "the frame". Optional.
@export var title := ""
@export var output: StringName
@export var output_count := 1
## Item id → amount consumed.
@export var inputs: Dictionary[StringName, int] = {}
@export var craft_time_sec := 2.0
## Optional sound sequence; replaces the station's loop sound and sets the craft time.
@export var phases: Array[CraftPhase] = []


func total_time() -> float:
	if phases.is_empty():
		return craft_time_sec
	var total := 0.0
	for phase in phases:
		total += phase.duration_sec
	return total


func can_craft() -> bool:
	for item in inputs:
		if GameState.count(item) < inputs[item]:
			return false
	return true


## Consumes the inputs. Returns false (and spends nothing) if any are missing.
func spend_inputs() -> bool:
	if not can_craft():
		return false
	for item in inputs:
		GameState.spend(item, inputs[item])
	return true


## e.g. "1 Yarrow (have 3)"
func describe_inputs() -> String:
	var parts: PackedStringArray = []
	for item in inputs:
		parts.append("%d %s (have %d)" % [inputs[item], Items.display_name(item), GameState.count(item)])
	return ", ".join(parts)
