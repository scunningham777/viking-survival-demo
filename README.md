# Viking Survival – SFX Demo

A small 2D top-down viking survival game for **Godot 4.7**. It's built to show off a sound-effects pack: every sound is
a named *event*, and replacing the audio means dropping files into folders. No code changes.

The art is placeholder (shapes drawn in code) and the audio is crude synthesized placeholders, so the game runs and makes
sound before any real assets exist.

## Running it

1. Install [Godot 4.7.x](https://godotengine.org/download) (standard build, not .NET).
2. Import → select this folder's `project.godot` → **Run** (F5).

Controls: **WASD/arrows** move · **Space/left click** swing axe · **E** feed the fire / harvest herbs · **F** eat meat ·
**1/2/3** use herbs (D-pad left/up/right) · **I** inventory (Back) · **Esc** menu · gamepad supported.

### Loop

Chop trees for wood → keep the campfire burning (it heals you) → wolves come at night (a war horn sounds) → kill them for
meat → eat before hunger empties. Survive as many days as you can.

**Crafting** happens at fixed stations. The first is the **cooking spit** beside the campfire: press **E** at it with raw
meat while the fire is lit, and after a few seconds cooked meat pops out (restores 60 hunger vs 35 raw; **F** eats cooked
meat first). Sounds: `spit_place`, `spit_sizzle_loop` (positional), `spit_done`, `pickup_cooked_meat`. New stations are
new scenes using `scenes/props/crafting_station.gd` with different exports (input, output, time, heat source, sounds).

Press **I** to open the inventory (the game pauses): a grid of everything you're carrying. Click an item to see what it
does. The satchel opening and closing plays `ui_inventory_open` / `ui_inventory_close`.

Wild herbs grow around the map and regrow after you pick them:

| Herb | Key | Effect | Sound events |
|---|---|---|---|
| Yarrow (white flowers) | 1 | Heals 30 | `herb_yarrow_pick`, `herb_yarrow_use` |
| Angelica (tall green umbels) | 2 | Restores 20 hunger | `herb_angelica_pick`, `herb_angelica_use` |
| Wolfsbane (purple spikes) | 3 | Poisons the axe: double damage for 20s | `herb_wolfsbane_pick`, `herb_wolfsbane_use`, `herb_wolfsbane_wear_off` |

## Swapping in the sound pack

```
audio/events/<event_id>/   ← every audio file here is a variation of that event
audio/sound_bank.tres      ← per-event tuning: bus, volume, pitch/volume jitter, rate limits, notes
```

1. `python tools/make_placeholder_sfx.py --clean` to delete the placeholders.
2. Copy the pack's files into the matching folders (`.wav`, `.ogg`, `.mp3`). For example, put all the axe impacts in
   `audio/events/axe_hit_wood/`. Several files per event = random variation, never the same file twice in a row.
3. Add music to `music_menu/`, `music_day/`, `music_night/` (currently empty, so the game warns once and stays silent).
4. Open the game's **Sound Browser** (main menu) to audition every event, fire it 5× to hear the variation, and balance
   the buses with the sliders. Tune per-event values in `audio/sound_bank.tres` in the Inspector.

To add a new sound: create `audio/events/<new_id>/`, add files, and call `AudioManager.play(&"new_id")` or
`AudioManager.play_at(&"new_id", global_position)`. Adding an entry to the bank is optional (it just sets the tuning).

### Audio API (`autoload/audio_manager.gd`)

| Call | Use |
|---|---|
| `play(id)` | Non-positional one-shot (UI, player sounds) |
| `play_at(id, pos)` | Positional one-shot: pans and fades with distance from the camera |
| `play_loop(id, node2d_or_null)` / `stop_loop(handle)` | Loops: attach to a node for positional (campfire), or global (wind) |
| `play_music(id)` / `stop_music()` | Crossfading music |
| `set_bus_volume(bus, 0..1)` | Mixer: buses are Master, Music, SFX, Ambience, UI |

Every button in the game automatically gets `ui_hover` / `ui_click`.

## Project layout

```
autoload/        AudioManager (sound events, pooling, loops, music) and GameState (inventory, day/night)
audio/           SoundEvent / SoundBank resources, sound_bank.tres, events/<id>/ audio folders
data/            item definitions (names, descriptions, inventory order)
scenes/actors/   player, wolf
scenes/props/    pine_tree, pickup, campfire, herb_plant, crafting_station (+ cooking_spit)
scenes/world/    world: level generation, day/night cycle, wolf spawning
scenes/ui/       main menu, sound browser, HUD, inventory panel
tests/           headless smoke test
tools/           placeholder sound generator
```

Physics layers: 1 world · 2 player · 3 enemies · 4 pickups · 5 interactables.

## Checking it without the editor

```
godot --headless --path . --import                       # first time only: imports assets
godot --headless --path . res://tests/smoke_test.tscn    # prints SMOKE TEST PASSED, exit code 0
```

## Shipping as a demo / template

- **Web (itch.io):** Project → Export → add *Web*, then export. The project uses the Compatibility renderer, so it runs
  in browsers. On the web, Godot plays sounds as browser "samples": pitch and volume variation still work, but effects
  on audio buses don't. Keep the buses effect-free, or test the effects in the web build.
- **As a template:** the code has no dependencies. Before publishing, pick a license for the code (e.g. MIT) and make
  sure the sound pack's license allows the files to be included in the download.

## Next ideas

- Real art: replace `_draw()` placeholders with `Sprite2D`/`AnimatedSprite2D`, and the ground with a `TileMapLayer`.
- Surface-aware footsteps (`footstep_snow` / `footstep_grass`) based on the tile under the player.
- More pack showcases: weather (blizzard bed), raven/eagle one-shots, draugr enemy, longship horn, shield block.
