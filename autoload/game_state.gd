extends Node
## Run-wide state (autoload "GameState"). The World calls reset() at the start of each run.

signal inventory_changed
signal time_of_day_changed(day: int, is_night: bool)
## Short feedback text for the HUD, e.g. "No wood to burn".
signal message(text: String)
## A multi-recipe CraftingStation wants the crafting screen (the HUD opens it).
signal craft_menu_requested(station: CraftingStation)

var items: Dictionary[StringName, int] = {}
var day := 1
var is_night := false


func reset() -> void:
	items = {&"wood": 0, &"meat": 0, &"cooked_meat": 0, &"yarrow": 0, &"angelica": 0, &"wolfsbane": 0,
			&"yarrow_poultice": 0, &"angelica_mash": 0, &"wolfsbane_paste": 0}
	day = 1
	is_night = false
	inventory_changed.emit()


func count(item: StringName) -> int:
	return items.get(item, 0)


func add(item: StringName, amount := 1) -> void:
	items[item] = count(item) + amount
	inventory_changed.emit()


func spend(item: StringName, amount := 1) -> bool:
	if count(item) < amount:
		return false
	items[item] -= amount
	inventory_changed.emit()
	return true


func set_time_of_day(new_day: int, night: bool) -> void:
	day = new_day
	is_night = night
	time_of_day_changed.emit(day, is_night)


func notify(text: String) -> void:
	message.emit(text)
