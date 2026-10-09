extends Node2D
## Run controller: builds the level, drives the day/night cycle and spawns wolves.

const WOLF_SCENE := preload("res://scenes/actors/wolf.tscn")
const TREE_SCENE := preload("res://scenes/props/pine_tree.tscn")
const HERB_SCENE := preload("res://scenes/props/herb_plant.tscn")
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

@export var world_half_size := Vector2(900, 900)
@export var tree_count := 70
## Trees are kept out of this radius around the campfire.
@export var clearing_radius := 150.0
## Plants of each herb variety (see HerbPlant.KINDS).
@export var herbs_per_kind := 7
## Herbs are kept out of this radius around the campfire.
@export var herb_clearing_radius := 70.0
@export_group("Day / night")
@export var day_length_sec := 60.0
@export var night_length_sec := 45.0
@export var day_tint := Color.WHITE
@export var night_tint := Color(0.22, 0.27, 0.45)
@export_group("Wolves")
@export var day_spawn_interval_sec := 20.0
@export var night_spawn_interval_sec := 6.0
@export var max_wolves := 8
## Spawn distance from the player (min, max) – just off screen.
@export var spawn_distance := Vector2(380, 460)

var _phase_time := 0.0
var _spawn_timer := 0.0
var _wind: Node

@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _tint: CanvasModulate = $DayNightTint
@onready var _hud: Hud = $HUD


func _ready() -> void:
	GameState.reset()
	_build_bounds()
	_scatter_trees()
	_scatter_herbs()
	_configure_camera()
	_hud.bind_player(_player)
	_hud.restart_requested.connect(_restart)
	_hud.menu_requested.connect(_to_menu)
	_player.died.connect(_on_player_died)
	_tint.color = day_tint
	_wind = AudioManager.play_loop(&"ambience_wind", null, 2.0)
	_begin_phase(1, false)


func _exit_tree() -> void:
	AudioManager.stop_loop(_wind)
	AudioManager.stop_music()


func _process(delta: float) -> void:
	if _player.is_dead:
		return
	_phase_time += delta
	if _phase_time >= (night_length_sec if GameState.is_night else day_length_sec):
		if GameState.is_night:
			_begin_phase(GameState.day + 1, false)
		else:
			_begin_phase(GameState.day, true)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = night_spawn_interval_sec if GameState.is_night else day_spawn_interval_sec
		if get_tree().get_node_count_in_group(&"wolves") < max_wolves:
			spawn_wolf()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_to_menu()
	elif _player.is_dead and event.is_action_pressed(&"restart"):
		_restart()


func spawn_wolf() -> void:
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(spawn_distance.x, spawn_distance.y)
	var margin := Vector2(20, 20)
	var wolf := WOLF_SCENE.instantiate() as Node2D
	wolf.position = (_player.position + offset).clamp(-world_half_size + margin, world_half_size - margin)
	_entities.add_child(wolf)


func _begin_phase(day: int, night: bool) -> void:
	_phase_time = 0.0
	_spawn_timer = night_spawn_interval_sec if night else day_spawn_interval_sec
	GameState.set_time_of_day(day, night)
	create_tween().tween_property(_tint, "color", night_tint if night else day_tint, 4.0)
	if night:
		AudioManager.play(&"war_horn")
		AudioManager.play_music(&"music_night")
		GameState.notify("Night falls – the wolves are hunting")
	else:
		AudioManager.play_music(&"music_day")
		if day > 1:
			GameState.notify("Dawn of day %d" % day)


func _on_player_died() -> void:
	AudioManager.stop_music(1.0)
	_hud.show_game_over(GameState.day)


func _restart() -> void:
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _scatter_trees() -> void:
	var placed := 0
	var attempts := 0
	while placed < tree_count and attempts < tree_count * 10:
		attempts += 1
		var pos := Vector2(randf_range(-world_half_size.x, world_half_size.x),
				randf_range(-world_half_size.y, world_half_size.y))
		if pos.length() < clearing_radius:
			continue
		var tree := TREE_SCENE.instantiate() as Node2D
		tree.position = pos
		_entities.add_child(tree)
		placed += 1


func _scatter_herbs() -> void:
	for kind in HerbPlant.KINDS:
		for i in herbs_per_kind:
			var pos := Vector2.ZERO
			while pos.length() < herb_clearing_radius:
				pos = Vector2(randf_range(-world_half_size.x, world_half_size.x),
						randf_range(-world_half_size.y, world_half_size.y))
			var herb := HERB_SCENE.instantiate() as HerbPlant
			herb.kind = kind
			herb.position = pos
			_entities.add_child(herb)


func _build_bounds() -> void:
	var w := world_half_size
	var t := 64.0  # wall thickness
	var walls := StaticBody2D.new()
	walls.name = "Bounds"
	walls.collision_mask = 0
	for rect: Rect2 in [
		Rect2(-w.x - t, -w.y - t, w.x * 2.0 + t * 2.0, t),  # top
		Rect2(-w.x - t, w.y, w.x * 2.0 + t * 2.0, t),  # bottom
		Rect2(-w.x - t, -w.y, t, w.y * 2.0),  # left
		Rect2(w.x, -w.y, t, w.y * 2.0),  # right
	]:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = rect.get_center()
		walls.add_child(collider)
	add_child(walls)


func _configure_camera() -> void:
	var camera := _player.get_node(^"Camera2D") as Camera2D
	camera.limit_left = int(-world_half_size.x)
	camera.limit_top = int(-world_half_size.y)
	camera.limit_right = int(world_half_size.x)
	camera.limit_bottom = int(world_half_size.y)


func _draw() -> void:
	# Placeholder ground: tundra with snow patches. Replace with a TileMapLayer.
	var rect := Rect2(-world_half_size, world_half_size * 2.0)
	draw_rect(rect, Color(0.33, 0.4, 0.31))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 140:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		draw_circle(p, rng.randf_range(12.0, 48.0), Color(0.86, 0.9, 0.94, 0.85))
