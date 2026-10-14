class_name InventoryPanel
extends PanelContainer
## Grid inventory (I / gamepad Back). Pauses the game while open.
##
## Inventory mode: clicking a slot selects it and shows the item's description.
## Crafting mode (open_station()): the side panel lists the station's recipes. Picking
## a recipe (or clicking one of its ingredients in the grid) shows what it makes and
## needs; the craft button starts it and closes the panel.

signal opened
signal closed

@export var slot_count := 12
@export var slot_size := Vector2(36, 36)
## Grid slots that aren't ingredients of the selected recipe are dimmed to this.
@export var unrelated_slot_alpha := 0.35

## Set false to block opening (e.g. after the player dies).
var can_open := true
var selected_item: StringName = &""
## The station whose recipes are shown, or null in inventory mode.
var station: CraftingStation
var selected_recipe: Recipe

var _slots: Array[Button] = []
var _slot_group := ButtonGroup.new()
var _recipe_group := ButtonGroup.new()

@onready var _title: Label = %Title
@onready var _grid: GridContainer = %Grid
@onready var _recipe_list: VBoxContainer = %RecipeList
@onready var _detail_icon: ItemIcon = %DetailIcon
@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _needs_label: Label = %NeedsLabel
@onready var _craft_button: Button = %CraftButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # stays interactive while the game is paused
	hide()
	_build_slots()
	_craft_button.pressed.connect(_craft_selected)
	GameState.inventory_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed(&"inventory") or event.is_action_pressed(&"ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
	elif can_open and not get_tree().paused and event.is_action_pressed(&"inventory"):
		open()
		get_viewport().set_input_as_handled()


## Opens in inventory mode.
func open() -> void:
	_open(null)


## Opens in crafting mode for `crafting_station`.
func open_station(crafting_station: CraftingStation) -> void:
	if can_open:
		_open(crafting_station)


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	AudioManager.play(&"ui_inventory_close")
	station = null
	closed.emit()


## Selects an item in the grid. In crafting mode this picks the first recipe that uses it.
func select(item: StringName) -> void:
	if station:
		for recipe in station.recipes:
			if recipe.inputs.has(item):
				select_recipe(recipe)
				return
		_refresh()  # not an ingredient here: restore the previous slot highlight
		return
	selected_item = item
	var slot := _slot_for(item)
	if slot:
		slot.set_pressed_no_signal(true)
	_show_details()


func select_recipe(recipe: Recipe) -> void:
	selected_recipe = recipe
	_refresh()


## Items currently shown in the grid, in slot order.
func shown_items() -> Array[StringName]:
	var items: Array[StringName] = []
	for slot in _slots:
		if not slot.get_meta(&"item", &"").is_empty():
			items.append(slot.get_meta(&"item"))
	return items


func _open(crafting_station: CraftingStation) -> void:
	if visible:
		return
	station = crafting_station
	_title.text = station.station_name if station else "Inventory"
	_build_recipe_list()
	show()
	get_tree().paused = true
	AudioManager.play(&"ui_inventory_open")
	_refresh()
	if station:
		_recipe_button_for(selected_recipe).grab_focus()
	else:
		var focus_slot := _slot_for(selected_item)
		(focus_slot if focus_slot else _slots[0]).grab_focus()
	opened.emit()


func _craft_selected() -> void:
	var crafting_station := station
	var recipe := selected_recipe
	if crafting_station == null or recipe == null or not recipe.can_craft():
		return
	close()  # unpause first so the station's sounds and timer run
	crafting_station.start(recipe)


func _build_slots() -> void:
	for i in slot_count:
		var slot := Button.new()
		slot.custom_minimum_size = slot_size
		slot.toggle_mode = true
		slot.button_group = _slot_group
		slot.pressed.connect(func() -> void: select(slot.get_meta(&"item", &"")))

		var icon := ItemIcon.new()
		icon.name = "Icon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		var count := Label.new()
		count.name = "Count"
		count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 2)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count.add_theme_font_size_override(&"font_size", 9)
		count.add_theme_constant_override(&"outline_size", 3)
		count.add_theme_color_override(&"font_outline_color", Color.BLACK)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)

		_grid.add_child(slot)
		_slots.append(slot)


## One toggle button per recipe at the current station; empty in inventory mode.
func _build_recipe_list() -> void:
	for child in _recipe_list.get_children():
		_recipe_list.remove_child(child)
		child.queue_free()
	_recipe_list.visible = station != null
	_needs_label.visible = station != null
	_craft_button.visible = station != null
	if station == null:
		return
	_craft_button.text = station.verb
	if selected_recipe not in station.recipes:
		selected_recipe = _first_craftable(station.recipes)
	for recipe in station.recipes:
		var button := Button.new()
		button.text = Items.display_name(recipe.output)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = _recipe_group
		button.set_meta(&"recipe", recipe)
		button.pressed.connect(select_recipe.bind(recipe))
		_recipe_list.add_child(button)


## Fills slots with every item the player has, in Items.ORDER; the rest stay empty.
func _refresh() -> void:
	var owned: Array[StringName] = []
	for item in Items.ORDER:
		if GameState.count(item) > 0:
			owned.append(item)
	for item: StringName in GameState.items:  # anything added without a definition
		if item not in owned and GameState.count(item) > 0:
			owned.append(item)

	var ingredients: Dictionary[StringName, int] = {}
	if station and selected_recipe:
		ingredients = selected_recipe.inputs
	for i in _slots.size():
		var slot := _slots[i]
		var item: StringName = owned[i] if i < owned.size() else &""
		slot.set_meta(&"item", item)
		slot.disabled = item.is_empty()
		slot.focus_mode = Control.FOCUS_NONE if item.is_empty() else Control.FOCUS_ALL
		slot.tooltip_text = Items.display_name(item) if not item.is_empty() else ""
		var highlighted := ingredients.has(item) if station else item == selected_item
		slot.set_pressed_no_signal(not item.is_empty() and highlighted)
		slot.modulate.a = unrelated_slot_alpha if station and not item.is_empty() and not highlighted else 1.0
		(slot.get_node(^"Icon") as ItemIcon).item = item
		var count := GameState.count(item)
		(slot.get_node(^"Count") as Label).text = str(count) if count > 1 else ""

	if not selected_item.is_empty() and selected_item not in owned:
		selected_item = &""
	for button in _recipe_list.get_children():
		var recipe: Recipe = button.get_meta(&"recipe")
		button.set_pressed_no_signal(recipe == selected_recipe)
		button.modulate.a = 1.0 if recipe.can_craft() else 0.5
	_show_details()


func _show_details() -> void:
	if station:
		_show_recipe_details()
		return
	var has_item := not selected_item.is_empty()
	_detail_icon.item = selected_item
	_name_label.text = Items.display_name(selected_item) if has_item else "Nothing selected"
	_count_label.text = "Carrying %d" % GameState.count(selected_item) if has_item else ""
	_description_label.text = Items.description(selected_item) if has_item \
			else "Select an item to see what it does."


func _show_recipe_details() -> void:
	var recipe := selected_recipe
	_detail_icon.item = recipe.output if recipe else &""
	_name_label.text = Items.display_name(recipe.output) if recipe else "No recipes"
	_count_label.text = "Carrying %d" % GameState.count(recipe.output) if recipe else ""
	_description_label.text = Items.description(recipe.output) if recipe else ""
	_needs_label.text = "Needs: %s" % recipe.describe_inputs() if recipe else ""
	_craft_button.disabled = recipe == null or not recipe.can_craft()


func _first_craftable(recipes: Array[Recipe]) -> Recipe:
	for recipe in recipes:
		if recipe.can_craft():
			return recipe
	return recipes[0] if not recipes.is_empty() else null


func _slot_for(item: StringName) -> Button:
	if item.is_empty():
		return null
	for slot in _slots:
		if slot.get_meta(&"item", &"") == item:
			return slot
	return null


func _recipe_button_for(recipe: Recipe) -> Button:
	for button in _recipe_list.get_children():
		if button.get_meta(&"recipe") == recipe:
			return button
	return _craft_button
