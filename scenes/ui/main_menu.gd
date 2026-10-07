extends Control

const WORLD := "res://scenes/world/world.tscn"
const SOUND_BROWSER := "res://scenes/ui/sound_browser.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _sounds_button: Button = %SoundsButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_play_button.pressed.connect(get_tree().change_scene_to_file.bind(WORLD))
	_sounds_button.pressed.connect(get_tree().change_scene_to_file.bind(SOUND_BROWSER))
	_quit_button.pressed.connect(get_tree().quit)
	_quit_button.visible = not OS.has_feature("web")
	_play_button.grab_focus()
	AudioManager.play_music(&"music_menu")
