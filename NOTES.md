# arglebargle: development notes

A 2D game engine written in Odin with `vendor:raylib`. It uses only Odin `core:` and `vendor:` packages.

## Goal

Entity scripts are plain Odin procedures written in a blocking style. They run alongside the update/draw loop, the player's movement, and each other:

```odin
glide_away :: proc(self: engine.Entity_Id) {
	player := engine.player()
	engine.set_tint(player, rl.RED)                              // immediate
	engine.move_entity(self, {4, 0}, 1.0, .Quadratic_In_Out)     // 4 tiles; blocks until arrival
	engine.pause(2)                                              // blocks for 2 game seconds
	engine.set_tint(player, rl.WHITE)
}
```

A general tween system (position, scale, rotation, tint, alpha, raw `^f32`) supports both scripts and ordinary game code.

## Building

```sh
./build.sh          # run the demo (debug)
./build.sh build    # debug build  -> build/arglebargle
./build.sh release  # optimized build
./build.sh test     # headless engine tests (ODIN_TEST_THREADS=1, because engine state is global)
```

Every target first runs `src/build_tools/process_sprites.py`, which needs Python 3 and the `aseprite` CLI on `PATH`. It exports each `assets/sprites/*.ase` to a PNG sheet next to it, and generates `src/engine/sprite_data.odin`. Both outputs are gitignored.

Demo controls: WASD or the arrow keys move the player one tile at a time, and Z talks to whatever the player is facing. Z also closes a dialogue box; while one is showing, the player can't move or talk. F1 toggles the debug overlay: grid lines, trigger outlines, the faced tile, and each live script's wait state.

## Layout

| Path | Contents |
|---|---|
| `src/main.odin` | Window, frame loop, and a tracking allocator in debug builds |
| `src/engine/world.odin` | `World` global state, `init` / `shutdown` / `update` |
| `src/engine/clock.odin` | Game time: dt clamp (1/20 s), pause, time scale |
| `src/engine/entity.odin` | `Entity`, stored in `core:container/handle_map`; deferred destroy |
| `src/engine/sprite.odin` | Sprite types, sheet loading with palette swaps, `Sprite_State` animation, y- and layer-sorted drawing |
| `src/engine/sprite_data.odin` | Generated: the `Sprite_Name` enum and the `sprite_metadata` table |
| `src/engine/tween.odin` | Tweens over `[4]f32` lanes, easing from `core:math/ease` |
| `src/engine/script.odin` | Script runtime (thread handoff) |
| `src/engine/script_api.odin` | Verbs: immediate (`set_*`) and blocking (`pause`, `move_entity`, ...) |
| `src/engine/grid.odin` | Tile size, zoom, `Tile`, `Direction`, tile/world conversions |
| `src/engine/effects.odin` | Screen flash overlay |
| `src/engine/dialogue.odin` | Dialogue box: the `say` verb, word-wrapped drawing |
| `src/engine/trigger.odin` | Talk triggers: `interact` runs the faced entity's script |
| `src/engine/debug.odin` | F1 overlay |
| `src/engine/engine_test.odin` | 36 headless tests |
| `src/game/` | Demo scene setup, player input, example scripts |
| `src/build_tools/` | `process_sprites.py` (Aseprite to PNG sheets plus `sprite_data.odin`) |
| `assets/sprites/` | Aseprite sources for the demo sprites |

## Key design decisions

### Tile grid
- Tiles are 16 px square (`TILE_SIZE`). World units are native pixels, and a `rl.Camera2D` at `ZOOM = 4` scales them up. The 1280x720 window shows 20 x 11.25 tiles, with the camera fixed at the origin.
- Each entity has `tile` (its logical cell) and `pos` (its visual position, in pixels). `spawn_entity` places `pos` at `tile_center(tile)`.
- Grid moves (`tween_to_tile`, `move_entity`, `walk_entity`) set `tile` the moment the move starts, and the sprite slides after it. `walk_entity` steps one tile at a time, so a walking NPC's tile always matches where it's drawn. Its optional `pause_between` waits between tiles, but not after the last one.
- `walk_route(id, route, seconds_per_tile, pause_between)` walks a closed loop of corner tiles once: `route[0]`, `route[1]`, and so on, back to `route[0]`. Adjacent corners, including last to first, must differ only in x or only in y (this is asserted), so each leg is a straight `walk_entity`. With `pause_between` it also pauses at each corner, but not after the final tile. The entity should start on `route[0]`; loop the call to patrol forever.
- Raw `.Pos` tweens are for visual effects only and don't change `tile`.
- Entities have a `facing` direction. For the player, it's the direction they last tried to move.
- The player moves in smooth tile steps (`STEP_TIME` 0.15 s). Input is read only between steps.
- There are no movement collisions yet: entities can share a tile.

### Talk triggers
Pressing Z calls `engine.interact(player)`. The first entity on the tile the player faces that has a trigger turns to face the player and runs its script.
- A trigger never runs its script twice at once.
- `Trigger_Mode` is `Repeat`, `Once` or `Cooldown`.
- The engine itself doesn't read input; the game decides when to call `interact`.

### Handles, never pointers
Entities, tweens and scripts each live in a `hm.Dynamic_Handle_Map` (`Entity_Id`, `Tween_Id` and `Script_Id` are `distinct hm.Handle32`). A zero handle means "none". Code keeps only handles. An `^Entity` from `entity_get` is valid only for the current scope and must never be held across a script yield.

### Referring to other entities by name
`engine.find(name)` does a linear scan of the entity map. It returns `Entity_Id{}` and logs a warning when no entity has that name, and if two share a name the first one wins. A script calls it once at the top and keeps the handle; it's never used per frame. Example: `trap_button` finds `"alarm_light"` and blinks it.

### Script runtime: thread handoff
Odin's core library has no coroutines. Instead, each running script gets an OS thread, and **only one thread runs at a time**:

- The main thread's `scripts_update()` resumes each script whose wait is satisfied, in spawn order, and blocks until that script yields or returns. The handoff uses two `sync.Sema` per script.
- So scripts can touch game state without locks, and execution order is deterministic.
- Waits: game time, next frame, a tween, another script, or a predicate evaluated on the main thread.
- Cancellation is cooperative. Every blocking verb returns `bool`, which is `false` once the script is cancelled (entity destroyed, `script_cancel`, shutdown). After a cancel, waits still yield one frame, so a loop that ignores the result can't freeze the game.
- In debug builds, a watchdog logs any script that runs for 2 s without yielding.

Rules for script bodies: no raylib GPU or draw calls (the GL context belongs to the main thread), no `^Entity` held across a wait, and every loop must reach a blocking verb.

### Tweens
- One code path for scalars, vectors and colors: values are `[4]f32` lanes, and colors are clamped and rounded back to `u8`.
- Modes are `Once`, `Loop` and `Ping_Pong`. Options are `delay` and `relative`. `from` is captured when the tween actually starts, after its delay.
- A new tween on the same target replaces the existing one. A tween whose entity is gone ends itself.
- `tween_done` is true once a tween has finished, been cancelled or replaced, or lost its target.

### Sprites
An entity's `sprite` is a `Sprite_State`. It holds which sheet and frame to show, the playback state, and the draw transforms (`tint`, `origin`, `scale`, `rotation`, `flip_x`/`flip_y`, `layer`, `hidden`). Tweens and the `set_*` verbs act on the transforms.
- **Names and metadata:** sprites are named by the generated `Sprite_Name` enum. There's one member per `.ase` file, named from the file name in title case (`patroller.ase` becomes `.Patroller`). The generated table `sprite_metadata: [Sprite_Name]Sprite_Metadata` holds `{filename, frame_size, type, tags, num_frames, frame_t}` for each. Adding a sprite means adding an `.ase` file; there's no registration code.
- **From Aseprite:** the type is decided per file.
  - A file with tags becomes `Tagged`, with one row per tag. Tag names must match `Sprite_Tag` members exactly (`Left`, `Down`, ...).
  - A file without tags becomes `Anim` if it has several frames, or `Static` if it has one.
  - `frame_t` comes from the frame durations. The tool assumes they're all equal.
- **Sheet layout:** frames run left to right and tags top to bottom, in the order of `tags`. There are three types:
  - `Static`: one frame.
  - `Anim`: one row of `num_frames[0]` frames.
  - `Tagged`: one row per tag, each with its own frame count.
  - `frame_t` is milliseconds per frame.
- **Loading:** `create_sprite_state(.Name, tag, palette, tint, play, speed, follow_facing, layer)` loads `assets/sprites/<filename>.png` the first time. The loaded `Sprite` keeps a copy of its metadata. Sprites without a palette swap are cached by name; palette-swapped ones (`Palette_Swap`, a list of from/to colors applied on load) get their own texture.
  - Loading uploads a texture, so it must happen on the main thread. Scripts must never trigger a load; the game can load up front with `preload_sprite`.
  - Without a window, for example in tests, `create_sprite_state` returns a state with no sheet that draws nothing.
- **Playback:**
  - `sprites_update` advances every entity's animation on game time. `update_sprite` reports when a row loops.
  - Control it with `play_sprite`, `stop_sprite`, `freeze_sprite`, `unfreeze_sprite` and `set_sprite_tag`.
  - Scripts can use the entity-level wrappers `play_anim`, `stop_anim`, `freeze_anim` and `set_sprite_tag_of`.
  - `animation_length` gives the duration of the current row.
- **Facing:** with `follow_facing`, the tag tracks the entity's facing (the Left/Down/Right/Up rows) without restarting playback.
- **Storage:** images and sprites live in `World` handle maps (`world.images`, `world.sprites`). The unswapped cache is `world.sprite_handles: [Sprite_Name]Sprite_Handle`.

Demo sprites in `assets/sprites/`:
- **Chest, light and flasher** are white shapes that tints color. The crate is a static checker, and the flasher is a 4-frame `Anim` pulse.
- **The button** has Up and Down rows. The trap button's script switches it to `.Down` while the alarm blinks.
- **The patroller sheet** has rows Left/Down/Right/Up, each a 2-frame idle bob, with a sky-blue body.
  - The player (white, so script tints show true), the route patroller (lime) and the villager (pink) are palette swaps of it, all made by `character_sprite` in `src/game/sprites.odin`.
  - All four characters use `follow_facing`, so the player's sprite turns with input.
- **The patrollers' movement:** the first patroller turns at each end of its patrol and toward the player when talked to. It steps one tile every 0.4 s, with a 0.25 s pause between moves, including at the turnarounds. The lime patroller loops `PATROL_ROUTE` (in `src/game/scripts.odin`) with `walk_route` at the same pace, pausing at corners and between laps.

### Dialogue
`say(text, speaker = "")` shows `text` in a box along the bottom of the screen and blocks the script until the box is dismissed, so consecutive `say` calls play as a conversation.
- Only one box shows at a time. If another script's box is up, `say` waits for it to close first.
- If the speaking script is cancelled, its box closes and `say` returns `false`.
- The engine doesn't read input. The game calls `dialogue_dismiss()` on Z, and skips movement and `interact` while `dialogue_active()`. The Z press that starts a conversation doesn't also dismiss its first line, because Z only counts on the frame it's pressed.
- The text is word-wrapped, with the speaker's name in gold and a blinking "Z" prompt. The box fits a speaker line plus about two lines of text, so split longer speeches into several `say` calls.
- The text string belongs to the speaking script and only needs to stay valid while that script is waiting in `say`.

Demo: the pink villager at (10, 5) says two lines.

### Screen flash
`flash_screen(color, duration)` covers the screen with `color` and fades it out over `duration`.
- The script waits until the flash has faded.
- `tween_flash` does the same but returns immediately, for game code or a script that shouldn't wait.
- The flash starts at the color's own alpha, so pass a lower alpha to keep the scene visible underneath.
- It runs on game time, so pausing the game pauses a flash.
- A new flash replaces one already in progress.
- It's drawn in screen space, after the world and before the debug HUD.

Demo: talking to the magenta "flasher" flashes a random bright color for 0.25 s.

### Frame order
1. `clock_advance`
2. game input / update (player steps, Z → `interact`)
3. tweens
4. scripts
5. sprite animations
6. flush destroyed entities
7. draw. Inside `BeginMode2D(camera)`: floor, entities, debug world overlay. Then, in screen space, the screen flash, the dialogue box and the HUD.

## Status

Done: entity handle map, sprites, tile grid with 4x camera, smooth tile-step player movement with facing, tween system, script runtime, blocking verbs, talk triggers (`Repeat`, `Once`, `Cooldown`), sprite sheets with tags, animation and palette swaps, screen flash, dialogue (`say`), deferred destroy with cancellation, watchdog, debug overlay, tests.

Known limitations / next steps:
- TODO: cache palette-swapped sprites by name and palette. Today every `create_sprite_state` call with a palette swap loads a new texture.
- `PATROL_ROUTE` is a package-level array read by one script, so entities can't each have their own route yet.
- No movement collisions; the camera doesn't follow the player.
- Holding a direction can pause for one frame between steps.
- No thread reuse pool yet: each spawned script creates an OS thread.
- `Handle32` has a 16-bit generation counter, so a slot's generation wraps after 65,536 reuses. Switch to `Handle64` if tween churn gets that high.
- Overlapping properties (`.Pos` vs `.Pos_X`) aren't detected as conflicting. Two scripts tweening the same property cut each other off, and the cut-off script's wait returns `true`.
- Ideas: timeline/sequence helpers, a dialogue box that grows with the text and dialogue choices, camera tweens via `tween_f32`. The script backend (minicoro or stackless) could be swapped behind the same verb API if wasm or very large script counts are ever needed.
