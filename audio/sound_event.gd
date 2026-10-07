class_name SoundEvent
extends Resource
## One named sound in the game (e.g. "axe_hit_wood") and how it should be played.
##
## Leave [member streams] empty to auto-load every audio file found in
## res://audio/events/<id>/ at startup (the normal workflow). Only fill it in to
## point an event at files that live somewhere else.

@export var id: StringName
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"SFX"
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db := 0.0
## Random +/- pitch change per play (0.05 = ±5%). Stops repeated sounds feeling robotic.
@export_range(0.0, 0.5, 0.01) var pitch_jitter := 0.05
## Random +/- volume change per play.
@export_range(0.0, 12.0, 0.5, "suffix:dB") var volume_jitter_db := 0.0
## Ignore play requests that arrive sooner than this after the previous one.
@export_range(0.0, 2.0, 0.01, "suffix:s") var min_interval_sec := 0.0
## Max simultaneous instances of this event (0 = unlimited).
@export_range(0, 16) var max_instances := 4
## Positional sounds fade to silence at this distance from the camera.
@export var max_distance := 900.0
## Free-form notes, e.g. which files from the vendor pack belong to this event.
@export_multiline var notes := ""
