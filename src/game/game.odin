package game

import "core:math/linalg"
import rl "vendor:raylib"
import "../engine"

PLAYER_SPEED :: 180

setup :: proc() {
	img := rl.GenImageChecked(24, 24, 6, 6, rl.ORANGE, rl.BROWN)
	crate := engine.texture_add(rl.LoadTextureFromImage(img))
	rl.UnloadImage(img)

	player := engine.spawn_entity({
		name   = "player",
		pos    = {480, 400},
		sprite = engine.sprite_rect({24, 24}, rl.WHITE, layer = 1),
	})
	engine.set_player(player)

	engine.spawn_entity({
		name    = "glider",
		pos     = {200, 200},
		sprite  = engine.sprite_from_texture(crate),
		trigger = {script = glide_away, radius = 60},
	})
	engine.spawn_entity({
		name    = "glider 2",
		pos     = {200, 330},
		sprite  = engine.sprite_from_texture(crate),
		trigger = {script = glide_away, radius = 60},
	})

	patroller := engine.spawn_entity({
		name    = "patroller",
		pos     = {560, 150},
		sprite  = engine.sprite_rect({28, 28}, rl.SKYBLUE),
		trigger = {script = spin, radius = 50, mode = .Cooldown, cooldown = 1},
	})
	engine.spawn(patrol, patroller, "patrol")

	chest := engine.spawn_entity({
		name    = "chest",
		pos     = {760, 330},
		sprite  = engine.sprite_rect({20, 16}, rl.GOLD),
		trigger = {script = vanish, radius = 40, mode = .Once},
	})
	// A plain tween started from game code, no script involved.
	engine.tween_by(chest, .Pos_Y, {-6, 0, 0, 0}, 0.6, .Sine_In_Out, .Ping_Pong)

	// The button's script finds the light by name.
	engine.spawn_entity({
		name    = "trap button",
		pos     = {640, 460},
		sprite  = engine.sprite_rect({22, 10}, rl.GRAY),
		trigger = {script = trap_button, radius = 18},
	})
	engine.spawn_entity({
		name    = "broken trap button",
		pos     = {760, 460},
		sprite  = engine.sprite_rect({22, 10}, rl.GRAY),
		trigger = {script = broken_trap_button, radius = 18},
	})
	engine.spawn_entity({
		name   = "alarm_light",
		pos    = {900, 50},
		sprite = engine.sprite_rect({18, 18}, ALARM_OFF),
	})
}

update :: proc() {
	if rl.IsKeyPressed(.F1) do engine.toggle_debug()

	dir: [2]f32
	if rl.IsKeyDown(.LEFT)  || rl.IsKeyDown(.A) do dir.x -= 1
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) do dir.x += 1
	if rl.IsKeyDown(.UP)    || rl.IsKeyDown(.W) do dir.y -= 1
	if rl.IsKeyDown(.DOWN)  || rl.IsKeyDown(.S) do dir.y += 1
	if dir != 0 do dir = linalg.normalize(dir)

	if p, ok := engine.entity_get(engine.player()); ok {
		p.pos += dir * PLAYER_SPEED * engine.dt()
	}
}
