class_name SoundBank
extends Resource
## Registry of every SoundEvent in the game (res://audio/sound_bank.tres).
## Edit it in the Inspector to tune buses, volumes and pitch variation.

@export var events: Array[SoundEvent] = []
