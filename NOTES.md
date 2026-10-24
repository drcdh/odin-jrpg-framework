# odin-jrpg-framework: development notes

A 2D JRPG written in Odin with `vendor:raylib`. Downstream repos merge this one and override or add content. It uses only Odin `core:` and `vendor:` packages.

## Goal

Entity scripts are plain Odin procedures written in a blocking style. They run alongside the update/draw loop, the player's movement, and each other:

```odin
glide_away :: proc(self: Entity_Id) {
	player := player()
	set_tint(player, rl.RED)                              // immediate
	move_entity(self, {4, 0}, 1.0, .Quadratic_In_Out)     // 4 tiles; blocks until arrival
	pause(2)                                              // blocks for 2 game seconds
	set_tint(player, rl.WHITE)
}
```

A general tween system (position, scale, rotation, tint, alpha, raw `^f32`) supports both scripts and ordinary game code.

## Building

```sh
./build.sh          # run the demo (debug)
./build.sh build    # debug build  -> build/odin-jrpg
./build.sh release  # optimized build
./build.sh test     # checks src/rules is headless, then the rules and game tests (ODIN_TEST_THREADS=1, because state is global)
```

Every target first runs the generators. They need Python 3, the `aseprite` CLI on `PATH`, and `pytiled_parser`. All of their outputs are gitignored.
- `src/build_tools/process_sprites.py` exports each `assets/sprites/*.ase` to a PNG sheet next to it, and generates `src/game/sprite_data.odin`.
- `src/build_tools/process_audio.py` turns the files in `assets/audio/sounds/` and `assets/audio/music/` into `src/game/sound_data.odin` (`Sound_Name`, `sound_files`) and `music_data.odin` (`Music_Name`, starting with `None`, and `music_files`). Each file's name becomes its enum value: `door_knock.wav` is `Door_Knock`.
- `src/build_tools/process_items.py` and `process_skills.py` turn `content/consumables.csv`, `equippables.csv` and `skills.csv` into `src/rules/item_data.odin` (`Item_Name`, `items`) and `skill_data.odin` (`Skill_Name`, `skills`). `process_skills.py` also writes each skill's sound (the `sound` column) to `src/game/skill_sound_data.odin` (`skill_sounds`), since sounds are presentation.
- `src/build_tools/process_tiled.py` exports each `assets/tilesets/*.ase` to a PNG, and turns each `assets/tiled/<Level>/<room>.tmx` into `src/game/level_<level>_<room>_data.odin`. It also writes `src/game/level_data.odin`, `encounter_region_data.odin` and `tileset_data.odin`, and `src/rules/levels_data.odin` (the `Level` enum) and `chest_data.odin`.

Controls are the old game's: the arrow keys move the player one tile at a time, and Z talks to whatever the player is facing. Z also turns dialogue pages and picks choices, and Up/Down move through choices; while a box is showing, the player can't move or talk. S opens the world menu, and X closes it (see World menu). A gamepad works too (see Input). Debug builds only: F1 toggles the debug overlay (grid lines, trigger outlines, the faced tile, and each live script's wait state), F4 saves to `saves/test.json` and F5 loads it, and the old game's debug keys work (see `debug.odin`): C prints the PCs, F/G/T toggle the framerate bar, a UI-tile grid and a font sample, 1–6 add or remove party members, and backtick toggles the FPS cap (vsync and `THROTTLED_FPS`, or neither).

A new game opens with a cutscene in Quarry (`src/game/level_quarry_main.odin`, played whenever Quarry is entered until the `Introduction` flag is set): no player; the screen opens black and fades in once Dude and a stranger are already walking. Dude walks into the quarry's yard and meets a stranger while they talk, the camera following Dude; dialogue waits for Z. After the talk the camera pans slowly right as the screen fades, and Grove starts with the player and Dude, who paces `dude_route_0`, near boxes holding items and a warp pad. Doors, warp pads and map edges connect Grove, Overworld, Cave, House and Quarry. The earlier demo entities (patrollers, villager, flasher, gliders) no longer spawn, and their sprites are gone, but their scripts are still in `src/game/scripts.odin`.

## Packages

| Package | Holds | Imports |
|---|---|---|
| `src/rules` | Headless state and mechanics: anything that can matter to battle state. `Game_Data` (flags, money, chests, inventory, party membership), the playable characters with their stats, equipment, status and charged skills, items, skills and targeting types, save files and their metadata, the `Level` and `Chest_Datum` enums; later enemies, and battle state and resolution. Its globals are freed with `rules.destroy()`, which `game.shutdown` calls. No clocks, no real time, no raylib, so battles can run programmatically | `core:` only |
| `src/game` | Everything real-time and audiovisual: the world, entities, scripts, tweens, tiles and the screen size, maps, input, player control, level changes and fades, UI and menus, the levels and their NPC scripts, sprites, the generated level code, `save_game` / `load_game` around `rules`' save files, sound and music; later battle presentation | `rules` |
| `src/main.odin` | The window and the frame loop | `game` |

`game` calls `rules`, and `rules` calls nothing: there are no hooks or callbacks between them. Content splits along the same line: item, skill and enemy tables go in `rules`, while their sprites, the levels and the NPC scripts go in `game`. `./build.sh test` checks that `src/rules` builds alone (`odin check`) and imports neither `../game`, `vendor:raylib` nor `core:time`.

## Layout

| Path | Contents |
|---|---|
| `src/main.odin` | Window, frame loop, and a tracking allocator in debug builds |
| `src/game/world.odin` | `World` global state, `init` / `shutdown` / `update` |
| `src/game/camera.odin` | Camera focus (an entity or a tile), snaps and timed pans, CLAMP clamping (`camera_follow`, `camera_to_tile`, `camera_update`) |
| `src/game/clock.odin` | Game time: dt clamp (1/20 s), pause, time scale; `raw_dt` for the UI |
| `src/game/entity.odin` | `Entity`, stored in `core:container/handle_map`; deferred destroy |
| `src/game/sprite.odin` | Sprite types, sheet loading with palette swaps, `Sprite_State` animation, y- and layer-sorted drawing |
| `src/game/sprite_data.odin` | Generated: the `Sprite_Name` enum and the `sprite_metadata` table |
| `src/game/tween.odin` | Tweens over `[4]f32` lanes, easing from `core:math/ease` |
| `src/game/script.odin` | Script runtime (thread handoff) |
| `src/game/script_api.odin` | Verbs: immediate (`set_*`, `clear_trigger`) and blocking (`pause`, `move_entity`, `get_items`, ...) |
| `src/game/grid.odin` | Tile size, zoom, the 16 x 14 tile screen (`VIEW_TILES_*`, `WINDOW_WIDTH` / `WINDOW_HEIGHT`), `Tile`, `Direction`, tile/world conversions |
| `src/game/screen_effects.odin` | Screen flash, level-change curtain |
| `src/game/dialogue.odin` | Dialogue box: the `say` and `choose` verbs, typing, paging, word wrap, choice pane |
| `src/game/sound.odin` | Sound effects: `play_sound`, the queue in `world.audio`, volumes |
| `src/game/music.odin` | Music: `play_music`, fades, the music thread |
| `src/game/sound_data.odin`, `music_data.odin` | Generated by `process_audio.py`: `Sound_Name` / `Music_Name` and their files |
| `src/game/skill_sound_data.odin` | Generated: `skill_sounds`, each skill's sound |
| `src/game/skill_effects.odin` | `do_skill`: runs `rules.do_skill`, plays the skill's sound and animates the result for its `Skill_Context` (world menu popups; battles to come) |
| `src/game/input.odin` | `Game_Input` bindings (keyboard and gamepad), press/hold state, `get_input` |
| `src/game/text.odin`, `panes.odin`, `font.odin`, `ui_icons.odin` | UI drawing in UI tiles: text, bordered panes, the bitmap font, cursor icons |
| `src/game/font_data.odin` | Generated: the font's glyph table |
| `src/game/trigger.odin` | Talk triggers: `interact` runs the faced entity's script |
| `src/game/map.odin` | `Level_Map` (in `World`), `tile_free` / `tile_passable` / `tile_occupied`, `map_route`, map rendering to a render texture, `draw_map`, `Map_Mode` |
| `src/game/tileset_data.odin` | Generated: the `Tileset_Id` enum and `tileset_files` |
| `src/game/player.odin` | Player control: walking, talking, the F4/F5 save and load test keys (debug builds) |
| `src/game/save.odin` | `save_game` / `load_game`: the save point and real time around `rules`' save files |
| `src/game/selection.odin`, `input.odin` `grid_change` | Menu cursor helpers |
| `src/game/debug.odin` | F1 overlay, and the old game's debug keys (`debug_update`, `debug_draw`); debug builds only |
| `src/game/world_menu.odin`, `metadata_menu.odin` | The world menu; the save-slot summaries for its future Save screen |
| `src/game/level.odin` | `start_level` (optionally without a player) and `enter_level`, the player's spawn, `change_level` / `egress` / `warp_to_level`, fades, edge exits, level history (`world.levels`), `clear_level` |
| `src/game/start.odin` | `GAME_TITLE`, `start_game` (called by `main`), and `new_game` (resets the game data with `init_new_game` and starts Quarry without a player, which plays the intro cutscene) |
| `src/game/rules_aliases.odin` | Unqualified names for `rules` types and procs, for level code and scripts |
| `src/game/level_<level>_main.odin` | Hand-written `init_*` per level; Grove spawns the pacing dude, Quarry plays the opening cutscene until `Introduction` is set |
| `src/game/stubs.odin` | Placeholders for old-project features the generated level code calls (`try_spawn_from_save`) |
| `src/game/chests.odin` | `items_in_a_box`, the chests' trigger script |
| `src/game/scripts.odin`, `sprites.odin` | Example scripts; `walker_sprite`, the PCs' sprites (`pc_sprite`, `pc_battle_sprite`, `pc_menu_sprite`, `PC_PALETTES`) |
| `src/game/level_*_data.odin`, `level_data.odin`, `encounter_region_data.odin` | Generated by `process_tiled.py` |
| `src/game/game_test.odin` | 77 headless tests |
| `src/rules/data.odin` | `Game_Data` (story flags, numbers, money, inventory, party membership), `init_new_game`, save files, `destroy` |
| `src/rules/character.odin`, `party.odin` | `Character` (stats, level, equipment, status, skills), experience and levels; the six PCs (`playable_characters`), party membership, skill sets from equipment, step effects |
| `src/rules/stats.odin`, `equipment.odin`, `inventory.odin`, `item.odin`, `skill.odin`, `targeting.odin` | Stats and their modifiers, equipment slots, the inventory (counts capped at `MAX_ITEM_COUNT`, 99) and its display orders, items (consumables and equippables), charged skills, target types |
| `src/rules/skill_effects.odin` | Effect data and types, the damage formula, and the effect procs, which change the characters and return an `Effect_Result` |
| `src/rules/combatant.odin` | A temporary `Combatant` stub (a `Character` plus `ticks` and `windup`) until battles are ported |
| `src/rules/item_data.odin`, `skill_data.odin` | Generated from `content/*.csv` |
| `src/rules/rules_test.odin` | Headless tests: equipping, a save and load round trip, stat floors, item effects and stagger, item count limits. Tests set up their own state rather than relying on how a new game starts |
| `src/rules/metadata.odin` | Save-file summaries for the menu's Save screen |
| `src/rules/levels_data.odin`, `chest_data.odin` | Generated by `process_tiled.py`: the `Level` and `Chest_Datum` enums |
| `src/build_tools/` | `process_sprites.py`, `process_tiled.py` (with `passable.py`), `generate_font.py`, `processing.py` |
| `assets/sprites/` | Aseprite sources for the sprites |
| `assets/tiled/` | The Tiled project: one folder per level, one `.tmx` per room, object templates |
| `assets/tilesets/` | Aseprite sources for the tilesets |
| `assets/textures/` | Hand-made UI textures: `font.png`, `pane.png` |
| `assets/audio/` | `sounds/` and `music/`, named after their enum values; `CREDITS.md` lists each file's original name and source |

## Downstream repos
The game's downstream repos merge this one (for example, a private copy with this repo as its `upstream` remote) and override or add content. To keep those merges free of conflicts:
- Edit `src/game/start.odin` for the window title and for where a new game begins. This repo rarely touches it.
- Add content as new files: maps under `assets/tiled/<Level>/`, sprites and tilesets under `assets/sprites/` and `assets/tilesets/`, `src/game/level_<level>_<room>.odin`, and rules data (items, skills, enemies) in `src/rules`. The generators pick up the assets, and their output is gitignored.
- Leave the demo's files alone until the game no longer needs them, and make shared changes upstream.

## Key design decisions

### Tile grid
- Tiles are 16 px square (`TILE_SIZE`). World units are native pixels, and a `rl.Camera2D` at `ZOOM = 4` scales them up. The screen is a constant 16 x 14 tiles (`VIEW_TILES_W` x `VIEW_TILES_H`), so the window is 1024x896 (`WINDOW_WIDTH` x `WINDOW_HEIGHT`, all in `grid.odin`). The camera follows the player, or whatever a level or script points it at (see Camera under Maps and levels).
- Each entity has `tile` (its logical cell) and `pos` (its visual position, in pixels). `spawn_entity` places `pos` at `tile_center(tile)`.
- Grid moves (`tween_to_tile`, `move_entity`, `walk_entity`) set `tile` the moment the move starts, and the sprite slides after it. `walk_entity` steps one tile at a time, so a walking NPC's tile always matches where it's drawn. Its optional `pause_between` waits between tiles, but not after the last one.
- `walk_route(id, route, seconds_per_tile, pause_between, once = false)` walks a closed loop of corner tiles once: `route[0]`, `route[1]`, and so on, back to `route[0]`. With `once` it stops on the last corner instead, so the route needn't close (an open path, as in the intro cutscene). Every leg it walks must differ only in x or only in y (this is asserted), so each is a straight `walk_entity`. With `pause_between` it also pauses at each corner, but not after the final tile. The entity should start on `route[0]`; loop the call to patrol forever.
- Raw `.Pos` tweens are for visual effects only and don't change `tile`.
- Entities have a `facing` direction. For the player, it's the direction they last tried to move.
- The player moves in smooth tile steps (`STEP_TIME` 0.15 s). Input is read only between steps.
- The player can't step onto impassable tiles (see Maps and levels). Scripted moves ignore map passability.
- **Entities block each other** unless either one has `ghost = true`. `tile_occupied(t, mover)` is true when a solid entity other than `mover` is on `t`. A ghost mover is never blocked, and a ghost never blocks. Because `tile` changes when a move starts, a tile being walked onto is already taken, so two movers can't claim the same tile.
  - The player's input checks `tile_free(to, player)`: passable and not occupied.
  - `walk_entity`, and so `walk_route`, waits before each step (`wait_tile_clear`) until the next tile is clear, then carries on. A pacing NPC stops in front of the player and resumes once the player moves.
  - `move_entity`, `move_entity_to` and `tween_to_tile` don't check occupancy. They're for scripted effects such as the glider's slide.

### Talk triggers
Pressing Z calls `interact(player)`. The first entity on the tile the player faces that has a trigger runs its script.
- A trigger never runs its script twice at once.
- `Trigger` has `autoface` (turn to face the talker) and `autobusy` (busy for the trigger script, so the entity's other scripts can't move or turn it). Both happen in `interact`, before the script first runs.
- `new_trigger(script, autoface = true, autobusy = true)` is the usual way to make one. A bare `Trigger{script = ...}` does neither.
- When a trigger script finishes, its entity's busy flag is cleared, whoever set it.
- `interact` doesn't read input; player control calls it when `get_input(.ENTER)` is pressed.

### Busy entities
`set_busy(id)` (and `set_busy(id, false)`) stops an entity wandering or following a path while something interacts with it, such as the player talking to it.
- While busy, every script but the one that set it is held off:
  - `move_entity` and `move_entity_to`, and so `walk_entity` and `walk_route`, wait as if blocked, and carry on when the entity is free. A step already under way finishes first. `wait_not_busy(id)` waits the same way.
  - `set_facing` (and so `set_facing_player`) does nothing.
  - Nothing else is affected: other verbs, raw tweens and `set_busy` itself still work.
- The holding script may move and turn the entity as usual. The main thread is never held off.
- `is_busy(id)` tells whether anything holds the entity. The game checks it for the player: while a script holds the player (`set_busy_player()` / `set_busy_player(false)`), player control (`player.odin`) ignores movement and interact input, for example during a scripted pause with no dialogue box up. A step already under way finishes.
- Busy lapses when the holding script ends, so a cancelled talk script can't leave the entity stuck. Set from the main thread, busy holds off all scripts until cleared.

Demo: Grove's dude has a `new_trigger`, so talking to him makes him face the player and stop pacing until the conversation ends.

### Handles, never pointers
Entities, tweens and scripts each live in a `hm.Dynamic_Handle_Map` (`Entity_Id`, `Tween_Id` and `Script_Id` are `distinct hm.Handle32`). A zero handle means "none". Code keeps only handles. An `^Entity` from `entity_get` is valid only for the current scope and must never be held across a script yield.

### Referring to other entities by name
`find(name)` does a linear scan of the entity map. It returns `Entity_Id{}` and logs a warning when no entity has that name, and if two share a name the first one wins. A script calls it once at the top and keeps the handle; it's never used per frame. Example: `trap_button` finds `"alarm_light"` and blinks it.

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
- **Names and metadata:** sprites are named by the generated `Sprite_Name` enum. There's one member per `.ase` file, named from the file name in title case (`player_world.ase` becomes `.Player_World`). The generated table `sprite_metadata: [Sprite_Name]Sprite_Metadata` holds `{filename, frame_size, type, tags, num_frames, frame_t}` for each. Adding a sprite means adding an `.ase` file; there's no registration code.
- **From Aseprite:** the type is decided per file.
  - A file with tags becomes `Tagged`, with one row per tag. Tag names must match `Sprite_Tag` members exactly (`Left`, `Down`, ...).
  - A file without tags becomes `Anim` if it has several frames, or `Static` if it has one.
  - `frame_t` comes from the frame durations. The tool assumes they're all equal.
- **Sheet layout:** frames run left to right and tags top to bottom, in the order of `tags`. There are three types:
  - `Static`: one frame.
  - `Anim`: one row of `num_frames[0]` frames.
  - `Tagged`: one row per tag, each with its own frame count.
  - `frame_t` is milliseconds per frame.
- **Loading:** `create_sprite_state(.Name, tag, palette, tint, play, speed, follow_facing, layer)` loads `assets/sprites/<filename>.png` the first time. The loaded `Sprite` keeps a copy of its metadata. Sprites without a palette swap are cached by name. Palette-swapped ones (`Palette_Swap`, a list of from/to colors applied on load) are cached by name and a hash of the palette (`world.swapped_sprites`), so respawning a character on every level change reuses its texture.
  - Loading uploads a texture, so it must happen on the main thread. Scripts must never trigger a load; the game can load up front with `preload_sprite`.
  - Without a window, for example in tests, `create_sprite_state` returns a state with no sheet that draws nothing, and `get_sprite_h` adds a sprite record with no image.
- **Playback:**
  - `sprites_update` advances every entity's animation on game time. `update_sprite` reports when a row loops.
  - Control it with `play_sprite`, `stop_sprite`, `freeze_sprite`, `unfreeze_sprite` and `set_sprite_tag`.
  - Scripts can use the entity-level wrappers `play_anim`, `stop_anim`, `freeze_anim` and `set_sprite_tag_of`.
  - `animation_length` gives the duration of the current row.
- **Facing:** with `follow_facing`, the tag tracks the entity's facing (the Left/Down/Right/Up rows) without restarting playback.
- **Storage:** images and sprites live in `World` handle maps (`world.images`, `world.sprites`). The unswapped cache is `world.sprite_handles: [Sprite_Name]Sprite_Handle`.

Sprites in `assets/sprites/` (ported from the old game):
- **Walkers** (`Player_World`, `Dude`, `Man_Ps`) have rows Left/Down/Right/Up, each a 2-frame bob; Dude also has `Downed`. `walker_sprite(name, palette, layer, tag = .Down)` (`src/game/sprites.odin`) plays them with `follow_facing`, so they turn with their entity. The player is `Player_World` (layer 1), Dude is `Dude`.
- **The PCs' sprites:** walking (`pc_sprite`): PC 0 is `Player_World`, PCs 1–5 are `Man_Ps`. Battle (`pc_battle_sprite`, idling; `pc_menu_sprite` uses it for the world menu): PC 0 is `Player_Battle`, PCs 1–5 are `Man_Battle_Ps`. `Man_Ps` and `Man_Battle_Ps` are greyscale templates sharing the `TEMPLATE_*` colors (hair 238, shirt 221, skin 187, trousers 204), and each of PCs 1–5 has a constant palette swap from `PC_PALETTES` for both.
- **Battle sprites** (`Player_Battle`, `Man_Battle_Ps`) are 24×24 with rows Idle, Walk, RArm, LArm, Cheer, Kneeled and Downed; 1.5 UI tiles square in the menus.
- **Box** has Closed and Opened rows (chests); **Warp** is a 3-frame `Anim` (warp pads).
- **The button** has Up and Down rows; Grove's buttons switch to `.Down` when talked to. **Sign** and **Jukebox** are static.
- `boat` and `fire` came over too but aren't used yet.

### Dialogue
`say(text, speaker = "", hurry = false, pause = 0, clear = true)` types `text` into a pane across the top of the screen, one character every `DIALOGUE_SPEED` (0.05 s), and blocks the script until the player has read it. Consecutive `say` calls play as one conversation, because the box only closes once the speaking script stops talking.
- The box holds `DEFAULT_DIALOGUE_LINES` (4) lines. A speaker's name takes the first line, in gold, which leaves three lines for text.
- Words wrap at spaces (`wrap_page`), and `"\n"` breaks a line. Text that doesn't fit is split into pages: a "more" icon shows at the end of each page, and Z turns the page.
- Z while the text is typing shows the whole page at once. The press that opens the box (talking to someone) is consumed, so it doesn't skip the text.
- `hurry` returns as soon as the text is out, without waiting for Z. `pause` holds the finished text that many seconds first.
- `clear = false` carries on typing the page on screen instead of starting a new one.
- `choose(text, choices, speaker = "") -> (int, bool)` is like `say`, then lists `choices` in a pane under the text. Up and Down move the highlight (yellow; wraps around), and Z picks.
- Only one box shows at a time. If another script's box is up, `say` and `choose` wait for it to close first.
- If the speaking script is cancelled, its box closes and the verb returns `false`.
- The box copies the text, speaker and choices, so the strings needn't outlive the call.
- The box reads input itself (Z, Up and Down). The game skips movement and `interact` while `dialogue_active()`.
- Without a window (tests) the box still runs, with a 38-character line width, but draws nothing.

Demo: Grove's introduction says "You're new in town… Press Z to start!" the first time Grove is entered.

### Input
`input.odin` maps the old game's bindings to `Game_Input` values, on the keyboard and gamepad alike:

| Input | Key | Gamepad |
|---|---|---|
| `ENTER` | Z | right face down |
| `CANCEL` | X | right face right |
| `MENU` | S | right face up |
| `PAUSE` | Space | middle right (start) |
| `UP` / `DOWN` / `LEFT` / `RIGHT` | arrow keys | D-pad |

- `main` calls `input_update(dt)` once per frame, before `game.update`. Each input is `Input_Up`, `Input_Pressed` (this frame only) or `Input_Held{t}`.
- `get_input(k)` is true on the press and, once held for `HOLD_TIME` (1 s), on every frame after. `get_input(k, down = true)` is true on every frame it's held, which is what walking uses.
- `consume_input(k)` swallows the current press.
- `get_menu_input`, `get_x_input` and `get_y_input` read pressed directions for menus.
- `get_input` plays `.UI_Blip` when it returns true, unless `silent` is set. Walking passes `silent = true`.
- F1 (debug overlay) is still read straight from raylib.

### UI drawing
UI positions are in UI tiles: one zoomed tile, 64 px, so a glyph is half a tile and the 1024x896 screen is 16 x 14 tiles. Negative coordinates count from the right or bottom edge (`ui_to_screen`).
- `text.odin`: `draw_text`, `draw_text_center`, `draw_text_rjust`.
- `panes.odin`: `draw_pane(l, t, w, h)` draws a bordered box from the 8 px pieces of `assets/textures/pane.png`.
- `font.odin`: the 8x8 bitmap font in `assets/textures/font.png`. Its glyph table, `font_data.odin`, is generated by `generate_font.py`.
- `ui_icons.odin`: `UI` in `World` holds the font, the pane texture and the animated icons (the dialogue "more" icon, the menu cursor, and the tile-selection arrows). `draw_text_indicator` and `draw_tile_indicator` draw the cursors.
- The textures are embedded with `#load` and loaded by `init` only when there's a window.

### World menu
The player's menu outside of battle (`world_menu.odin`). MENU (S) opens it with `world_menu_enter`, but only when the player is free: no dialogue up, not stepping or being moved, and not `is_busy`. CANCEL (X) closes it (`world_menu_exit`).
- **Pause:** opening it pauses the clock and closing restores the clock's earlier state, so tweens and scripts wait. `ui_update` runs on `Clock.raw_dt` (clamped, unscaled, unpaused), so the cursor still animates.
- **Input:** while it's open, player control ignores input, and `world_menu_update` (after `dialogue_update`) reads UP/DOWN and CANCEL.
- **Drawing:** each screen is drawn into a `WINDOW_WIDTH` x `WINDOW_HEIGHT` render texture when it's stale, then blitted by `draw_world_menu` after the dialogue box. The textures load in `ui_init` (with a window only); headless, the menu works but draws nothing.
- **Screens:**
  - **Top:** the party (sprite, name, HP), the commands (Items, Skills, Status, System, Save), and time, steps and cash.
  - **Items:** the inventory with descriptions; consumables usable in the world are white. ENTER on one picks a party member (the targeting strip) and uses it (`do_skill`, see Skill effects). The result pops up over the member's sprite.
  - **Status:** a member's level, HP, equipment and stats. ENTER picks a slot's item, with a preview of the stat changes (`change_tint`).
  - **Skills:** a member's skills, their charge and descriptions.
  - **Save:** the save files (`rules.metadata`) and New Save.
  - **System:** empty.
- The menu reads and changes `rules` state directly. Presentation stays in `game`: PC menu sprites (`pc_menu_sprite` in `sprites.odin`), colors, and sounds (`.Blerp` for an item that can't be used, the skill's `skill_sounds` entry when one is). `selection.odin` and `grid_change` (`input.odin`) are the cursor helpers.

### Skill effects
`rules` works an effect out and `game` shows it:
- `rules.do_skill(actor, target, skill)` (`src/rules/skill_effects.odin`) rolls, changes the target and returns an `Effect_Result`: hit, miss or evade, the HP change, whether the target went down, the status outcome, levels gained, and for Combatants whether they were staggered or interrupted. What would have been text on screen in the old game is logged instead. `actor` is nil for an item.
- `do_skill`, `do_effect` and `effect_attack` are proc groups with a `Character` and a `Combatant` version. Only the Combatant version staggers (takes `ticks`, may break the `windup`) and rolls for a counter (still a stub); the world menu passes Characters. `Combatant` (`combatant.odin`) is a stub until battles are ported; its `using c: Character` comes first, so a `^Combatant` passes as a `^Character`.
- `game.do_skill(actor, target_party_idx, skill, ctx)` (`src/game/skill_effects.odin`) calls `rules.do_skill`, plays `skill_sounds[skill]` and animates the result by `Skill_Context`. In the world menu that's popups over the target's sprite in the targeting strip (`world_menu_popup`), 0.4 s apart: Miss/Evade in gray, damage in white, healing in green, "+N LV" and Ineff!/Resist!/Miss in purple, an added status in red, "Cured" in green. They rise and fade over a second on `raw_dt`, and the strip stays up until they're done. Battle presentation is a TODO.
- `VERBOSE` (`-define:VERBOSE=true`) logs the damage formula.

### Sound and music
`play_sound(name, delay = 0)` (`src/game/sound.odin`) queues a sound effect in `world.audio.pending`.
- `sounds_update` (after the dialogue box) counts the delays down on game time, so a paused world holds them, and plays what's due.
- Only the main thread calls raylib, so scripts can call `play_sound` from their threads.
- Each sound loads (`rl.LoadSound`) from `assets/audio/sounds/` the first time it plays; `shutdown` unloads them. A file that won't load logs a warning.
- `main` opens the audio device after the window and closes it after `game.shutdown`. Without a device (headless tests) due sounds are dropped silently.
- `world.audio.effects_volume` (0..`SOUND_MAX_VOLUME`, 10) applies to each sound as it plays.
- **Music** (`src/game/music.odin`) streams on its own thread, so it doesn't stutter on long frames (the Cat & Onion pattern). The game and scripts only store requests in atomics; the thread does every raylib music call, every 10 ms.
  - `play_music(name)` switches tracks (`.None` is silence). Asking for the track already playing does nothing, so each level's `init_*` requests its music on every entry: Overworld plays `.Overworld`, Grove, House and Quarry `.Town`, and Cave `.None`. `.Battle` waits for battles.
  - `play_prev_music()` goes back to the track before the current one.
  - `music_fade_down()` fades to silence over a second, and the music stays silent across track changes until `music_fade_up()`. Grove's healing fades the music around the warp sound.
  - `set_music_volume(v)` (0..`SOUND_MAX_VOLUME`, default 7).
  - Tracks load from `assets/audio/music/` with `rl.LoadMusicStream` and loop. The thread starts in `init` only if there's an audio device; `shutdown` joins it, and the thread unloads the stream.
- **Adding audio:** drop a file into `assets/audio/sounds/` or `music/` (the name becomes the enum value), rerun `./data_build.sh`, and add its source to `assets/audio/CREDITS.md`. Sound effects are 44.1 kHz 16-bit WAV (`LoadSound` decodes them into memory anyway, so lossless costs only disk); convert a new one with `ffmpeg -i in.ext -ar 44100 -c:a pcm_s16le -map_metadata -1 out.wav`. Music stays MP3.

### Screen flash
`flash_screen(color, duration)` covers the screen with `color` and fades it out over `duration`.

`fade_screen(alpha, duration)` (blocking) tweens the curtain to `alpha`: `fade_screen(0, t)` fades in, `fade_screen(1, t)` fades to black. `set_curtain(alpha)` (immediate, safe on the main thread) sets it at once and cancels a fade under way; a cutscene that should open dark calls `set_curtain(1)` after `start_level`, starts its action, then fades in.
- The script waits until the flash has faded.
- `tween_flash` does the same but returns immediately, for game code or a script that shouldn't wait.
- The flash starts at the color's own alpha, so pass a lower alpha to keep the scene visible underneath.
- It runs on game time, so pausing the game pauses a flash.
- A new flash replaces one already in progress.
- It's drawn in screen space, after the world and before the debug HUD.

Demo: talking to the magenta "flasher" flashes a random bright color for 0.25 s.

### Maps and levels
A **map** is a Tiled tilemap. A **level** is everything starting it adds to the world: the rendered map layers, the doors and other entities, their scripts and routes. Leaving the level removes all of it.

Each `assets/tiled/<Level>/<room>.tmx` becomes one member of the generated `Level` enum, so `Grove/main.tmx` becomes `.Grove_Main`. The levels are Grove, Overworld, Cave, House and Quarry, all `main` rooms.

- **Generated code** (`level_<level>_<room>_data.odin`):
  - named points as constants (`GROVE_MAIN_PLAYER_SPAWN_INTRO`)
  - routes from polylines and polygons
  - the tile layers, and a passability table
  - `tiled_init_<lr>`: calls `set_map` with the map's size, tilesets, routes, passability table, mode and `open_edges`. It also sets `world.levels.edge` and spawns the door entities and chests (see Chests).
  - `render_<lr>`: draws every layer into the map's render texture through `begin_map_render`, `draw_map_tile` and `end_map_render`
  - `<lr>_player_spawn`: the entrance rules
- **`level_data.odin`:** `tiled_init_level`, `init_level`, `render_level`, and `player_spawn_level` dispatch. Its switches are `#partial`, since the `Level` enum (`src/rules/levels_data.odin`) also lists any level a door or edge names that has no map.
- **Names:** the generated code is in package `game`, and reaches `rules` names through `rules_aliases.odin`.
- **Stale outputs:** the generator first deletes old `level_*_data.odin`, `level_data.odin` and `encounter_region_data.odin` files from `src/game` and `src/rules`, and any `*_data.odin` left in the old `src/engine` and `src/content` (removing those directories once empty), so renamed or removed maps and the old package layout leave nothing behind.
- **Map properties** (custom properties on each `.tmx`):
  - `edge_level`: where stepping off the map goes. It's `Level` or `Level/room`, with the room defaulting to `main`; empty means the edges are walls.
  - `map_mode`: `DEFAULT`, `CLAMP` or `WRAP`.
  - Grove and House have `Overworld` and `CLAMP`, Quarry has `Overworld` and `DEFAULT` (so the intro's camera can pan past the yard), Overworld has no edge and `WRAP`, and Cave has no edge and `DEFAULT`.
- **Doors** are point objects using the `DOOR.tx` template. `door_idx` pairs an exit in one level with the matching entrance in another.
  - `DOOR` is two-way; `DOOR-OUT` is an exit (egress) only, and `DOOR-IN` is an entrance (ingress) only.
  - `level`/`room` name the other side, defaulting to overworld/main; with only `room` set, the level is this one.
  - **Egress:** a ghost entity on the door tile whose `on_step` calls `warp_to_level` (if `warp` is set) or `egress(dest, door_idx)` when the player steps onto it. A warp pad (`warp` set) also shows the animated `Warp` sprite under whoever stands on it.
  - **Ingress:** a rule in `<lr>_player_spawn`: if `world.levels.prev`, `.egress_idx` and (when `eFace` is set) `.prev_face` match, spawn on the door tile facing `iFace`, one tile further in that direction if `iOffset` is set. Edge exits use `eFace` to choose where along the edge the player comes in.
- **Leaving a level** (`src/game/level.odin`):
  - `change_level(l, at = nil, face = .Down, fade = FADE_TIME)` queues a level change: it sets `world.levels.pending` (with the spawn tile, facing and fade time) and fades the curtain to black over `fade`. It's the way for a script to change levels, since `start_level` would cancel the calling script. With no `at`, the entrance rules pick the spawn. Ignored while a change is under way.
  - `egress(l, idx)` / `warp_to_level(l, idx)` record the door index and call `change_level(l)` (`FADE_TIME` 0.25 s). `warp_to_level` also plays `.Warp`.
  - Stepping off the map edge is egress index 0 to `world.levels.edge`. Player control checks it when the player's step finishes (`check_edge_exit`).
  - `level_transition_update` runs at the top of player control. Once the fade-out finishes it calls `start_level` (at the pending spawn) and fades back in over the same time. It runs even without a player. Input is ignored until the fade-in is done.
- **Entering a level:** `start_level(l, at = nil, face = .Down, with_player = true)`
  1. records the previous level and the player's tile and facing
  2. `clear_level()` destroys all entities, cancels every script (they finish on the next update), removes every tween, and unloads the map
  3. `enter_level(l, at, face, with_player)`:
     1. runs the generated `tiled_init_level`, which sets the map and its passability table
     2. spawns the player (unless `with_player` is false, as for a cutscene): at `at` facing `face` if given (a new game and loading a save), otherwise by the entrance rules. If no rule matches, it logs an error and uses the map center.
     3. runs the hand-written `init_<lr>` (Grove adds the dude; Quarry plays the intro cutscene until `Introduction` is set; the other levels add nothing yet), then the generated `render_level`. Spawning the player also points the camera at it, before `init_<lr>`, so a level's init can call `camera_follow` on something else
  4. without a player the camera follows nothing until `init_<lr>` or a script calls `camera_follow`
- **Step triggers:** `Entity.on_step(self, by)` runs on the main thread, immediately, when another entity finishes a tile move onto its tile. That covers `tween_to_tile`, so player steps and every `walk_entity` step count. Spawning, `set_tile` and cancelled moves don't trigger it.
- **Drawing:** the whole map is rendered once into a render texture. `draw_map` (inside `BeginMode2D`) draws only the part the camera sees. Render textures are stored bottom-up, so it flips the source rect at draw time.
- **Map modes:**
  - `DEFAULT`: the background shows past the map's edges.
  - `CLAMP`: `camera_update` keeps the view inside the map, and centers a map smaller than the view.
  - `WRAP`: the render texture repeats. An entity that steps off one edge is moved to the other side when its step finishes (`entity_arrived`), so tiles stay in range for doors and spawn rules.
- **Passability:** `passable.py` builds each level's `PASSABLE` table from per-tileset tables (`TILESET_TERRAIN_PASSABLE`, ...) and ORs the flags of every layer except those named `Passable_*`. `PARTY_IMPASSABLE` (1) blocks walking; `BOAT_IMPASSABLE` (2) is for later.
  - The table is row-major `[w * h]u8` (`<LEVEL>_PASSABLE`), and `set_map` takes it as `Level_Map.passable`. It's data, not a callback; an empty slice means everything is passable.
  - `tile_passable(t)` checks it. In WRAP mode it wraps `t`; otherwise tiles outside the map are passable only if the level has an edge exit (`open_edges`). With no map loaded, every tile is passable.
  - The player's input calls `tile_free` before each step. A blocked step still turns the player.
- **Routes:** `map_route(i)` returns route `i` of the current map. The generated `<LEVEL>_<NAME>` constants give the indices, for example `GROVE_MAIN_DUDE_ROUTE_0`. In Grove, `pace_dude_route_0` walks the dude from `GROVE_MAIN_DUDE_SPAWN_NOT_MET` to the route's start, then loops `walk_route`. A two-point route paces out and back.
- **Camera** (`src/game/camera.odin`): `world.camera_focus` is what the camera centers on: an `Entity_Id` (its tweened `pos`, so it glides with each step) or a fixed `Tile` (its center). `camera_update` runs every frame and applies the CLAMP clamp to the focus.
  - `camera_follow(id, speed = 0, easing = .Linear)` and `camera_to_tile(tile, speed = 0, easing = .Linear)` set the focus. They're immediate, so usable on the main thread and in scripts. With `speed` 0 the camera snaps; otherwise it pans from where it is at `speed` tiles per second in game time (so pausing and time scale apply), then holds the focus. A new call mid-pan takes over from the current position.
  - A pan lerps towards the focus as it is each frame, so panning onto a walking entity still lands on it. Its duration is set from the clamped distance on its first frame.
  - `camera_panning()` is true during a pan; `camera_followed()` returns the followed entity, if any. If the followed entity dies, the camera stays put.
  - Blocking verbs: `pan_camera_follow(id, speed)` and `pan_camera_to_tile(tile, speed)` start a pan and wait for it to arrive.
  - `clear_level` clears the focus and any pan.
- **Curtain:** `curtain_to(alpha, seconds)` tweens `world.curtain` (0 clear, 1 black); scripts use `fade_screen` and `set_curtain`. `draw_screen_effects` draws it over the world and under the dialogue box.
- **Tilesets:** `Tileset_Id` and `tileset_files` are generated into `src/game/tileset_data.odin` from `assets/tiled/tilesets/*.tsx`. Each tileset's name is title-cased, and its file is the stem of its image's filename. A tileset's column count comes from its texture width. Textures load on first use, on the main thread.
- **Chests:** each Tiled CHEST object becomes a `Box` entity named `chest:<Level>_<Room>_<n>`, with a `Chest_Datum` of the same name. It shows Closed or Opened from the datum and blocks movement; a `hidden` chest is an invisible ghost. Until it's opened, talking to it runs `items_in_a_box(self, datum, items...)` (`src/game/chests.odin`): it sets the datum, shows Opened, clears its trigger, and gives the items with `get_items` (or says "Ooh, nothing!"). `get_items(items...)` (`script_api.odin`) is a script verb of its own: it adds the items and says "Got Potion x2, Tea!", grouping duplicates; Dude uses it to hand over his tea. `clear_trigger(id)` removes an entity's talk trigger, for one-time things like a chest. Chests with an `encounter` are plain item boxes for now (a TODO marks where `monster_in_a_box` goes).
- **Stubs:** `src/game/stubs.odin` keeps `try_spawn_from_save`, which the generated spawn code calls.

### Game data and saving
`game_data: Game_Data` (`src/rules/data.odin`) holds the story state: `Bool_Datum` flags, `Int_Datum` numbers, chests, money, steps and play time. Scripts read and write it with `get_game_data` / `set_game_data`. `init_new_game` resets it, and `new_game` (`start.odin`) calls it before the intro cutscene.
- `game.save_game(filename)` builds the `Save_Point` (the current level and the player's tile) and reads the clock, then `rules.save_game(save_point, time_saved, filename)` writes `Save_Data` (the game data, the save point and the time saved) as JSON to `saves/<filename>`, creating `saves/` if needed (it's gitignored). With no filename it writes a new uniquely named file.
- `game.load_game(filename)` calls `rules.load_game`, which reads the file (`read_saved_game_data`), restores the game data (`load_saved_game`) and returns the save point. It then calls `start_level` at the saved level and tile, facing Down. Both report failure by logging and returning `false`; nothing exits the game.
- The `game` side takes the time as an argument, so it never reads a clock.
- Levels are saved by name (`use_enum_names`). The flag and number arrays are saved by position, so add new `Bool_Datum` and `Int_Datum` values at the end, or older saves load into the wrong slots.
- The player's facing isn't saved; after a load they face Down.
- Saves also hold each PC's equipment, level, experience, hitpoints, name and status (`party_data`). Loading re-equips them without touching the inventory, which is saved separately.
- In debug builds, F4 / F5 in player control (`player.odin`) save to and load from `TEST_SAVE` (`test.json`). They're ignored during a level transition.

### Frame order
1. `clock_advance`, `input_update`
2. `game.update`:
   1. player control (a pending level change, edge exits, player steps and their party step effects (`rules.do_party_step_effects`: the step count, poison, skill charge), Z → `interact`, S → the world menu)
   2. tweens; tile moves that finish fire step triggers (doors)
   3. scripts
   4. dialogue box (typing, paging, choices; closes once its speaker stops talking)
   5. sounds that are due (music runs on its own thread)
   6. world menu input
   7. sprite animations; UI icon animations on `raw_dt`
   8. camera follow
   9. flush destroyed entities
3. draw. Inside `BeginMode2D(camera)`: map, entities, debug world overlay. Then, in screen space, the screen flash and curtain, the dialogue box, the world menu and the HUD.

## Status

Done: entity handle map, sprites, tile grid with 4x camera, smooth tile-step player movement with facing, tween system, script runtime, blocking verbs, talk triggers, busy entities, sprite sheets with tags, animation and palette swaps, screen flash, dialogue (`say`, `choose`) with the old game's top pane, typing and paging, old input bindings with gamepad support, Tiled maps with a camera that follows entities or tiles, snapping or panning, levels connected by doors, warps and map edges with a fade, game data with JSON saving and loading (F4/F5 test keys), the party, items and skills from the old game (`rules`), the world menu (items with their effects, status and equipment, skills, saving), skill effects (`rules`) with world-menu popups, sound effects and music, deferred destroy with cancellation, watchdog, debug overlay, tests.

Known limitations / next steps:
- `PATROL_ROUTE` is a package-level array read by one script, so entities can't each have their own route yet.
- Map passability only stops the player; scripted moves ignore it. Single-tween moves (`move_entity`, `tween_to_tile`) ignore other entities too.
- Encounters aren't ported, so chests with an encounter just give their items. Loading has no menu yet, only the F5 test key in debug builds. Battles (and so battle presentation of skill effects, stagger and counters) and play time aren't ported yet.
- In WRAP mode, entities near the seam pop across when one of them steps over it, since only the stepping entity is moved.
- Holding a direction can pause for one frame between steps.
- No thread reuse pool yet: each spawned script creates an OS thread.
- `Handle32` has a 16-bit generation counter, so a slot's generation wraps after 65,536 reuses. Switch to `Handle64` if tween churn gets that high.
- Overlapping properties (`.Pos` vs `.Pos_X`) aren't detected as conflicting. Two scripts tweening the same property cut each other off, and the cut-off script's wait returns `true`.
- No start menu yet: `start_game` goes straight to `new_game` and the intro cutscene, which can't be skipped yet. Once there is one, `new_game` will run only when the player starts a new game from it.
- Ideas: timeline/sequence helpers, The script backend (minicoro or stackless) could be swapped behind the same verb API if wasm or very large script counts are ever needed.
