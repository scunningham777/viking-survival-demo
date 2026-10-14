class_name Recipe
extends Resource
## One crafting recipe: consumes `inputs` from the inventory and produces
## `output_count` × `output` after `craft_time_sec`. Stations hold a list of these.

@export var output: StringName
@export var output_count := 1
## Item id → amount consumed.
@export var inputs: Dictionary[StringName, int] = {}
@export var craft_time_sec := 2.0


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
