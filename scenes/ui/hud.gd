class_name Hud
extends CanvasLayer
## In-game HUD: health/hunger bars, inventory, day counter, messages and the game-over panel.

signal restart_requested
signal menu_requested

var _message_tween: Tween

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _hunger_bar: ProgressBar = %HungerBar
@onready var _inventory_label: Label = %InventoryLabel
@onready var _day_label: Label = %DayLabel
@onready var _message_label: Label = %MessageLabel
@onready var _game_over_panel: Control = %GameOverPanel
@onready var _summary_label: Label = %SummaryLabel
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	_game_over_panel.hide()
	_message_label.modulate.a = 0.0
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.time_of_day_changed.connect(_on_time_of_day_changed)
	GameState.message.connect(show_message)
	_restart_button.pressed.connect(restart_requested.emit)
	_menu_button.pressed.connect(menu_requested.emit)
	_refresh_inventory()


func bind_player(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	player.hunger_changed.connect(_on_hunger_changed)
	_on_health_changed(player.health, player.max_health)
	_on_hunger_changed(player.hunger, player.max_hunger)


func show_message(text: String) -> void:
	_message_label.text = text
	_message_label.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.6)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.6)


func show_game_over(days_survived: int) -> void:
	_summary_label.text = "You survived %d day%s." % [days_survived, "" if days_survived == 1 else "s"]
	_game_over_panel.show()
	_restart_button.grab_focus()


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_hunger_changed(current: float, maximum: float) -> void:
	_hunger_bar.max_value = maximum
	_hunger_bar.value = current


func _refresh_inventory() -> void:
	_inventory_label.text = "Wood %d    Meat %d" % [GameState.count(&"wood"), GameState.count(&"meat")]


func _on_time_of_day_changed(day: int, is_night: bool) -> void:
	_day_label.text = "Day %d – %s" % [day, "Night" if is_night else "Day"]
