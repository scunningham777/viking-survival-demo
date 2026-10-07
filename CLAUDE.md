# Viking Survival – SFX Demo (Godot 4.7, GDScript)

Demo game for a sound-effects vendor's viking survival pack. Audio is the product, so audio code is the priority.

## Conventions
- **Sounds go through `AudioManager` by event id only.** Never reference audio file paths or create
  AudioStreamPlayers in gameplay code. New sound = new folder `audio/events/<id>/` (+ optional tuning entry in
  `audio/sound_bank.tres`). Use `play()` for player/UI sounds and `play_at()` for anything in the world.
- Typed GDScript (`:=`, typed params/returns), tabs, Godot style guide. Scripts live next to their scenes.
- Scenes are hand-editable `.tscn` text. Keep node paths stable; the scripts use `%UniqueName` for UI nodes.
- Placeholder visuals are `_draw()` calls; keep gameplay logic separate from drawing so sprites can replace them.
- Use en dashes (–) in user-facing text, not em dashes.
- Physics layers: 1 world, 2 player, 3 enemies, 4 pickups, 5 interactables.

## Verify changes
```
godot --headless --path . --import
godot --headless --path . res://tests/smoke_test.tscn   # must print SMOKE TEST PASSED
```
Extend `tests/smoke_test.gd` when adding gameplay systems. The "ObjectDB leaked / resources in use" lines at exit come
from sounds still playing when the test quits and can be ignored. "no audio for 'music_*'" warnings mean no music has
been added yet.
