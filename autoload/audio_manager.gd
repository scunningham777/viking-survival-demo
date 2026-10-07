extends Node
## Global audio service (autoload "AudioManager").
##
## Gameplay code never references audio files. It asks for a sound *event* by id:
##     AudioManager.play(&"axe_swing")                       # non-positional
##     AudioManager.play_at(&"wolf_growl", global_position)  # positional 2D
##     var loop := AudioManager.play_loop(&"campfire_loop", self)
##
## Each event's files are discovered from res://audio/events/<event_id>/. Every
## file in that folder is a variation; one is picked at random (never the same
## file twice in a row). Per-event tuning (bus, volume, pitch jitter, rate
## limiting) lives in res://audio/sound_bank.tres.
##
## Swapping in a commercial pack = deleting the placeholder_*.wav files and
## dropping the pack's files into the matching folders. No code changes.

const EVENTS_ROOT := "res://audio/events/"
const BANK_PATH := "res://audio/sound_bank.tres"
const AUDIO_EXTENSIONS: PackedStringArray = ["wav", "ogg", "mp3"]
const MAX_VOICES_PER_POOL := 24
const SILENT_DB := -60.0
## Buttons with this meta set to true are skipped by the automatic UI sounds.
const NO_UI_SOUND_META := &"no_ui_sound"

var _events: Dictionary[StringName, SoundEvent] = {}
var _last_variation: Dictionary[StringName, int] = {}
var _last_played_msec: Dictionary[StringName, int] = {}
var _warned: Dictionary[StringName, bool] = {}
var _global_voices: Array[Node] = []
var _positional_voices: Array[Node] = []
var _music_voice: Node
var _music_id: StringName


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep UI sounds working while paused
	_load_bank()
	_discover_streams()
	get_tree().node_added.connect(_on_node_added)


#region Playback

## Plays a one-shot that isn't placed in the world (UI, the player's own sounds).
func play(id: StringName, volume_offset_db := 0.0) -> AudioStreamPlayer:
	var event := _claim(id)
	if event == null:
		return null
	var voice := _acquire_voice(_global_voices, false) as AudioStreamPlayer
	_configure(voice, event, volume_offset_db)
	voice.play()
	return voice


## Plays a one-shot at a world position; it pans and fades with distance to the camera.
func play_at(id: StringName, world_position: Vector2, volume_offset_db := 0.0) -> AudioStreamPlayer2D:
	var event := _claim(id)
	if event == null:
		return null
	var voice := _acquire_voice(_positional_voices, true) as AudioStreamPlayer2D
	_configure(voice, event, volume_offset_db)
	voice.global_position = world_position
	voice.max_distance = event.max_distance
	voice.play()
	return voice


## Starts a looping event. Pass a Node2D to attach a positional loop to it (a
## campfire); omit it for a global bed (wind, music). Stop it with stop_loop().
## A fresh random variation is picked every time the loop wraps.
func play_loop(id: StringName, attach_to: Node2D = null, fade_in := 0.5) -> Node:
	var event := _find(id)
	if event == null:
		return null
	var voice: Node
	if attach_to:
		voice = AudioStreamPlayer2D.new()
		voice.max_distance = event.max_distance
		attach_to.add_child(voice)
	else:
		voice = AudioStreamPlayer.new()
		add_child(voice)
	_configure(voice, event, 0.0)
	# Re-trigger on finish so loops work whatever the file's import loop setting is.
	var retrigger := func() -> void:
		_configure(voice, event, 0.0)
		voice.play()
	voice.finished.connect(retrigger)
	voice.set_meta(&"retrigger", retrigger)
	var target_db: float = voice.volume_db
	voice.volume_db = SILENT_DB
	voice.play()
	voice.create_tween().tween_property(voice, "volume_db", target_db, fade_in)
	return voice


func stop_loop(voice: Node, fade_out := 0.5) -> void:
	if not is_instance_valid(voice) or voice.is_queued_for_deletion():
		return
	var retrigger: Callable = voice.get_meta(&"retrigger")
	if voice.finished.is_connected(retrigger):
		voice.finished.disconnect(retrigger)
	var tween := voice.create_tween()
	tween.tween_property(voice, "volume_db", SILENT_DB, fade_out)
	tween.tween_callback(voice.queue_free)


## Crossfades to a music event (an event on the Music bus, looped).
func play_music(id: StringName, fade := 2.0) -> void:
	if id == _music_id:
		return
	stop_music(fade)
	_music_id = id
	_music_voice = play_loop(id, null, fade)


func stop_music(fade := 2.0) -> void:
	stop_loop(_music_voice, fade)
	_music_voice = null
	_music_id = &""


## Stops every one-shot. Loops and music keep running.
func stop_all() -> void:
	for voice in _global_voices + _positional_voices:
		voice.stop()

#endregion


#region Mixer

## Sets a bus volume from a 0–1 slider value.
func set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


func get_bus_volume(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))

#endregion


#region Introspection (used by the Sound Browser)

func get_event_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_events.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func get_event(id: StringName) -> SoundEvent:
	return _events.get(id)

#endregion


func _load_bank() -> void:
	var bank := load(BANK_PATH) as SoundBank
	if bank == null:
		push_warning("AudioManager: sound bank missing at %s" % BANK_PATH)
		return
	for event in bank.events:
		if event != null and event.id != &"":
			# Runtime copy, so discovered streams never get saved back into the bank.
			_events[event.id] = event.duplicate() as SoundEvent


func _discover_streams() -> void:
	for entry in ResourceLoader.list_directory(EVENTS_ROOT):
		if not entry.ends_with("/"):
			continue
		var id := StringName(entry.trim_suffix("/"))
		var event: SoundEvent = _events.get(id)
		if event == null:
			event = SoundEvent.new()
			event.id = id
			_events[id] = event
		if not event.streams.is_empty():
			continue  # streams assigned explicitly in the bank take priority
		var folder := EVENTS_ROOT + entry
		var files := ResourceLoader.list_directory(folder)
		files.sort()
		for file in files:
			if file.get_extension().to_lower() in AUDIO_EXTENSIONS:
				var stream := load(folder + file) as AudioStream
				if stream != null:
					event.streams.append(stream)


## Returns the event if it has audio, warning once per missing event.
func _find(id: StringName) -> SoundEvent:
	var event: SoundEvent = _events.get(id)
	if event == null or event.streams.is_empty():
		if not _warned.has(id):
			_warned[id] = true
			push_warning("AudioManager: no audio for '%s' – add files to %s%s/" % [id, EVENTS_ROOT, id])
		return null
	return event


## Like _find(), but also applies the event's rate and polyphony limits.
func _claim(id: StringName) -> SoundEvent:
	var event := _find(id)
	if event == null:
		return null
	var now := Time.get_ticks_msec()
	var since_last: int = now - _last_played_msec.get(id, -1_000_000)
	if since_last < int(event.min_interval_sec * 1000.0):
		return null
	if event.max_instances > 0 and _count_playing(id) >= event.max_instances:
		return null
	_last_played_msec[id] = now
	return event


func _count_playing(id: StringName) -> int:
	var count := 0
	for voice in _global_voices + _positional_voices:
		if voice.playing and voice.get_meta(&"event", &"") == id:
			count += 1
	return count


func _acquire_voice(pool: Array[Node], positional: bool) -> Node:
	var voice: Node = null
	for candidate in pool:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		if pool.size() < MAX_VOICES_PER_POOL:
			if positional:
				voice = AudioStreamPlayer2D.new()
			else:
				voice = AudioStreamPlayer.new()
			add_child(voice)
		else:
			voice = pool[0]  # all busy: steal the voice that started longest ago
			voice.stop()
	pool.erase(voice)
	pool.append(voice)  # keeps the pool ordered oldest-start first
	return voice


func _configure(voice: Node, event: SoundEvent, volume_offset_db: float) -> void:
	voice.stream = _pick_variation(event)
	voice.bus = event.bus
	voice.volume_db = event.volume_db + volume_offset_db \
			+ randf_range(-event.volume_jitter_db, event.volume_jitter_db)
	voice.pitch_scale = 1.0 + randf_range(-event.pitch_jitter, event.pitch_jitter)
	voice.set_meta(&"event", event.id)


func _pick_variation(event: SoundEvent) -> AudioStream:
	var count := event.streams.size()
	var index := randi() % count
	if count > 1 and index == _last_variation.get(event.id, -1):
		index = (index + 1 + randi() % (count - 1)) % count
	_last_variation[event.id] = index
	return event.streams[index]


## Gives every button in the game hover/click sounds automatically.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.get_meta(NO_UI_SOUND_META, false):
		return
	button.pressed.connect(play.bind(&"ui_click"))
	button.mouse_entered.connect(play.bind(&"ui_hover"))
