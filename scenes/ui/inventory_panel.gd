class_name InventoryPanel
extends PanelContainer
## Grid inventory (I / gamepad Back). Pauses the game while open. Clicking a slot
## selects it and shows the item's description in the side panel.

signal opened
signal closed

@export var slot_count := 12
@export var slot_size := Vector2(36, 36)

## Set false to block opening (e.g. after the player dies).
var can_open := true
var selected_item: StringName = &""

var _slots: Array[Button] = []
var _slot_group := ButtonGroup.new()

@onready var _grid: GridContainer = %Grid
@onready var _detail_icon: ItemIcon = %DetailIcon
@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _description_label: Label = %DescriptionLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # stays interactive while the game is paused
	hide()
	_build_slots()
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


func open() -> void:
	if visible:
		return
	show()
	get_tree().paused = true
	AudioManager.play(&"ui_inventory_open")
	_refresh()
	var focus_slot := _slot_for(selected_item)
	(focus_slot if focus_slot else _slots[0]).grab_focus()
	opened.emit()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	AudioManager.play(&"ui_inventory_close")
	closed.emit()


func select(item: StringName) -> void:
	selected_item = item
	var slot := _slot_for(item)
	if slot:
		slot.set_pressed_no_signal(true)
	_show_details()


## Items currently shown in the grid, in slot order.
func shown_items() -> Array[StringName]:
	var items: Array[StringName] = []
	for slot in _slots:
		if not slot.get_meta(&"item", &"").is_empty():
			items.append(slot.get_meta(&"item"))
	return items


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


## Fills slots with every item the player has, in Items.ORDER; the rest stay empty.
func _refresh() -> void:
	var owned: Array[StringName] = []
	for item in Items.ORDER:
		if GameState.count(item) > 0:
			owned.append(item)
	for item: StringName in GameState.items:  # anything added without a definition
		if item not in owned and GameState.count(item) > 0:
			owned.append(item)

	for i in _slots.size():
		var slot := _slots[i]
		var item: StringName = owned[i] if i < owned.size() else &""
		slot.set_meta(&"item", item)
		slot.disabled = item.is_empty()
		slot.focus_mode = Control.FOCUS_NONE if item.is_empty() else Control.FOCUS_ALL
		slot.tooltip_text = Items.display_name(item) if not item.is_empty() else ""
		slot.set_pressed_no_signal(not item.is_empty() and item == selected_item)
		(slot.get_node(^"Icon") as ItemIcon).item = item
		var count := GameState.count(item)
		(slot.get_node(^"Count") as Label).text = str(count) if count > 1 else ""

	if not selected_item.is_empty() and selected_item not in owned:
		selected_item = &""
	_show_details()


func _show_details() -> void:
	var has_item := not selected_item.is_empty()
	_detail_icon.item = selected_item
	_name_label.text = Items.display_name(selected_item) if has_item else "Nothing selected"
	_count_label.text = "Carrying %d" % GameState.count(selected_item) if has_item else ""
	_description_label.text = Items.description(selected_item) if has_item \
			else "Select an item to see what it does."


func _slot_for(item: StringName) -> Button:
	if item.is_empty():
		return null
	for slot in _slots:
		if slot.get_meta(&"item", &"") == item:
			return slot
	return null
