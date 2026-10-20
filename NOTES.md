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

Demo controls: WASD or the arrow keys move the player one tile at a time, and Z talks to whatever the player is facing. F1 toggles the debug overlay: grid lines, trigger outlines, the faced tile, and each live script's wait state.

## Layout

| Path | Contents |
|---|---|
| `src/main.odin` | Window, frame loop, and a tracking allocator in debug builds |
| `src/engine/world.odin` | `World` global state, `init` / `shutdown` / `update` |
| `src/engine/clock.odin` | Game time: dt clamp (1/20 s), pause, time scale |
| `src/engine/entity.odin` | `Entity`, stored in `core:container/handle_map`; deferred destroy |
| `src/engine/sprite.odin` | `Sprite`, texture table, y- and layer-sorted drawing |
| `src/engine/tween.odin` | Tweens over `[4]f32` lanes, easing from `core:math/ease` |
| `src/engine/script.odin` | Script runtime (thread handoff) |
| `src/engine/script_api.odin` | Verbs: immediate (`set_*`) and blocking (`pause`, `move_entity`, ...) |
| `src/engine/grid.odin` | Tile size, zoom, `Tile`, `Direction`, tile/world conversions |
| `src/engine/trigger.odin` | Talk triggers: `interact` runs the faced entity's script |
| `src/engine/debug.odin` | F1 overlay |
| `src/engine/engine_test.odin` | 22 headless tests |
| `src/game/` | Demo scene setup, player input, example scripts |

## Key design decisions

### Tile grid
- Tiles are 16 px square (`TILE_SIZE`). World units are native pixels, and a `rl.Camera2D` at `ZOOM = 4` scales them up. The 1280x720 window shows 20 x 11.25 tiles, with the camera fixed at the origin.
- Each entity has `tile` (its logical cell) and `pos` (its visual position, in pixels). `spawn_entity` places `pos` at `tile_center(tile)`.
- Grid moves (`tween_to_tile`, `move_entity`, `walk_entity`) set `tile` the moment the move starts, and the sprite slides after it. `walk_entity` steps one tile at a time, so a walking NPC's tile always matches where it's drawn.
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

### Frame order
1. `clock_advance`
2. game input / update (player steps, Z → `interact`)
3. tweens
4. scripts
5. flush destroyed entities
6. draw. Inside `BeginMode2D(camera)`: floor, entities, facing marker, debug world overlay. Then the HUD in screen space.

## Status

Done: entity handle map, sprites, tile grid with 4x camera, smooth tile-step player movement with facing, tween system, script runtime, blocking verbs, talk triggers (`Repeat`, `Once`, `Cooldown`), deferred destroy with cancellation, watchdog, debug overlay, tests.

Known limitations / next steps:
- No movement collisions; the camera doesn't follow the player.
- Holding a direction can pause for one frame between steps.
- No thread reuse pool yet: each spawned script creates an OS thread.
- `Handle32` has a 16-bit generation counter, so a slot's generation wraps after 65,536 reuses. Switch to `Handle64` if tween churn gets that high.
- Overlapping properties (`.Pos` vs `.Pos_X`) aren't detected as conflicting. Two scripts tweening the same property cut each other off, and the cut-off script's wait returns `true`.
- Ideas: timeline/sequence helpers, a dialogue `say()` verb, camera tweens via `tween_f32`. The script backend (minicoro or stackless) could be swapped behind the same verb API if wasm or very large script counts are ever needed.
