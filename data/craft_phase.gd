class_name CraftPhase
extends Resource
## One step of a recipe's sound sequence, e.g. "saw for 1.5s, then hammer for 1.5s".
## The station plays `sound` from its position for `duration_sec`: looped when
## `interval_sec` is 0, otherwise as a one-shot repeated every `interval_sec`.

@export var sound: StringName
@export var duration_sec := 1.5
## 0 = play `sound` as a loop. > 0 = fire it as a one-shot this often (mallet thuds, chops).
@export var interval_sec := 0.0
