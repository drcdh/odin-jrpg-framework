package game

import rl "vendor:raylib"
import "../engine"

STEP_TIME :: 0.15 // seconds per tile

// The player's current step; while it runs, input is ignored.
player_step: engine.Tween_Id

setup :: proc() {
	img := rl.GenImageChecked(16, 16, 4, 4, rl.ORANGE, rl.BROWN)
	crate := engine.texture_add(rl.LoadTextureFromImage(img))
	rl.UnloadImage(img)

	player := engine.spawn_entity({
		name   = "player",
		tile   = {10, 8},
		sprite = engine.sprite_rect({14, 14}, rl.WHITE, layer = 1),
	})
	engine.set_player(player)

	engine.spawn_entity({
		name    = "glider",
		tile    = {3, 3},
		sprite  = engine.sprite_from_texture(crate),
		trigger = {script = glide_away},
	})
	engine.spawn_entity({
		name    = "glider 2",
		tile    = {3, 5},
		sprite  = engine.sprite_from_texture(crate),
		trigger = {script = glide_away},
	})

	patroller := engine.spawn_entity({
		name    = "patroller",
		tile    = {8, 2},
		sprite  = engine.sprite_rect({14, 14}, rl.SKYBLUE),
		trigger = {script = spin, mode = .Cooldown, cooldown = 1},
	})
	engine.spawn(patrol, patroller, "patrol")

	chest := engine.spawn_entity({
		name    = "chest",
		tile    = {16, 5},
		sprite  = engine.sprite_rect({12, 10}, rl.GOLD),
		trigger = {script = vanish, mode = .Once},
	})
	// A plain tween started from game code, no script involved.
	engine.tween_by(chest, .Pos_Y, {-2, 0, 0, 0}, 0.6, .Sine_In_Out, .Ping_Pong)

	// The button's script finds the light by name.
	engine.spawn_entity({
		name    = "trap button",
		tile    = {12, 9},
		sprite  = engine.sprite_rect({12, 6}, rl.GRAY),
		trigger = {script = trap_button},
	})
	engine.spawn_entity({
		name    = "broken trap button",
		tile    = {14, 9},
		sprite  = engine.sprite_rect({12, 6}, rl.GRAY),
		trigger = {script = broken_trap_button},
	})
	engine.spawn_entity({
		name   = "alarm_light",
		tile   = {19, 0},
		sprite = engine.sprite_rect({10, 10}, ALARM_OFF),
	})
}

update :: proc() {
	if rl.IsKeyPressed(.F1) do engine.toggle_debug()

	player := engine.player()
	if !engine.tween_done(player_step) do return

	if dir, held := held_direction(); held {
		// Facing is the direction the player last tried to move.
		engine.set_facing(player, dir)
		player_step = engine.tween_to_tile(player, engine.entity_tile(player) + engine.dir_vec(dir), STEP_TIME)
	} else if rl.IsKeyPressed(.Z) {
		engine.interact(player)
	}
}

// First held direction in a fixed order.
held_direction :: proc() -> (engine.Direction, bool) {
	if rl.IsKeyDown(.UP)    || rl.IsKeyDown(.W) do return .Up, true
	if rl.IsKeyDown(.DOWN)  || rl.IsKeyDown(.S) do return .Down, true
	if rl.IsKeyDown(.LEFT)  || rl.IsKeyDown(.A) do return .Left, true
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) do return .Right, true
	return {}, false
}

// World space, under the entities: a checkerboard floor covering the view.
draw_floor :: proc() {
	cam := engine.camera()
	cols := i32(f32(rl.GetScreenWidth()) / cam.zoom / engine.TILE_SIZE) + 1
	rows := i32(f32(rl.GetScreenHeight()) / cam.zoom / engine.TILE_SIZE) + 1
	for y in 0..<rows {
		for x in 0..<cols {
			color := rl.Color{38, 38, 50, 255} if (x + y) % 2 == 0 else rl.Color{44, 44, 58, 255}
			rl.DrawRectangle(x * engine.TILE_SIZE, y * engine.TILE_SIZE, engine.TILE_SIZE, engine.TILE_SIZE, color)
		}
	}
}

// World space, over the entities: a marker on the player's facing edge (no directional art yet).
draw_overlay_world :: proc() {
	p, ok := engine.entity_get(engine.player())
	if !ok do return
	d := engine.dir_vec(p.facing)
	center := p.pos + [2]f32{f32(d.x), f32(d.y)} * 5
	rl.DrawRectangleV(center - 2, {4, 4}, rl.DARKGRAY)
}
