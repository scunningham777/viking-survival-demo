extends Control
## Lists every sound event with buttons to audition it, plus per-bus volume
## sliders. Doubles as a "listen to the pack" page for the demo.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Ambience", &"UI"]
## How many times "×5" fires an event, to show off variation and pitch jitter.
const BURST_COUNT := 5
const BURST_SPACING_SEC := 0.28

@onready var _mixer: HBoxContainer = %Mixer
@onready var _event_list: VBoxContainer = %EventList
@onready var _stop_button: Button = %StopButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(get_tree().change_scene_to_file.bind(MAIN_MENU))
	_stop_button.pressed.connect(AudioManager.stop_all)
	_build_mixer()
	_build_event_list()
	_back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU)


func _build_mixer() -> void:
	for bus in BUSES:
		var column := VBoxContainer.new()
		var label := Label.new()
		label.text = bus
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 90.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = AudioManager.get_bus_volume(bus)
		slider.value_changed.connect(func(value: float) -> void: AudioManager.set_bus_volume(bus, value))
		column.add_child(label)
		column.add_child(slider)
		_mixer.add_child(column)


func _build_event_list() -> void:
	for id in AudioManager.get_event_ids():
		var event := AudioManager.get_event(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)

		var play_button := _make_audition_button("Play", func() -> void: AudioManager.play(id))
		var burst_button := _make_audition_button("×%d" % BURST_COUNT, _play_burst.bind(id))

		var name_label := Label.new()
		name_label.text = id
		name_label.custom_minimum_size.x = 150.0

		var info_label := Label.new()
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_label.clip_text = true
		if event.streams.is_empty():
			info_label.text = "no files – add to audio/events/%s/" % id
			info_label.modulate = Color(1.0, 0.6, 0.5)
			play_button.disabled = true
			burst_button.disabled = true
		else:
			info_label.text = "%d variation%s · %s bus" % [
					event.streams.size(), "" if event.streams.size() == 1 else "s", event.bus]
			info_label.modulate.a = 0.7
		if not event.notes.is_empty():
			info_label.tooltip_text = event.notes
			info_label.mouse_filter = Control.MOUSE_FILTER_PASS

		row.add_child(play_button)
		row.add_child(burst_button)
		row.add_child(name_label)
		row.add_child(info_label)
		_event_list.add_child(row)


func _make_audition_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.x = 40.0
	# Skip the automatic UI click so it doesn't mask the sound being auditioned.
	button.set_meta(AudioManager.NO_UI_SOUND_META, true)
	button.pressed.connect(on_pressed)
	return button


func _play_burst(id: StringName) -> void:
	for i in BURST_COUNT:
		AudioManager.play(id)
		await get_tree().create_timer(BURST_SPACING_SEC).timeout
		if not is_inside_tree():
			return
