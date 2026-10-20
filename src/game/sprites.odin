package game

import rl "vendor:raylib"
import "../engine"

// Placeholder sheets in assets/sprites. Plain shapes are white so tints color them.
PATROLLER_TAGS   := [?]engine.Sprite_Tag{.Left, .Down, .Right, .Up}
PATROLLER_FRAMES := [?]u16{2, 2, 2, 2}
FLASHER_FRAMES   := [?]u16{4}

register_sprites :: proc() {
	engine.register_sprite_metadata("player", {filename = "player", frame_size = {14, 14}, type = .Static})
	engine.register_sprite_metadata("chest",  {filename = "chest",  frame_size = {12, 10}, type = .Static})
	engine.register_sprite_metadata("button", {filename = "button", frame_size = {12, 6},  type = .Static})
	engine.register_sprite_metadata("light",  {filename = "light",  frame_size = {10, 10}, type = .Static})
	engine.register_sprite_metadata("crate",  {filename = "crate",  frame_size = {16, 16}, type = .Static})
	engine.register_sprite_metadata("flasher", {
		filename   = "flasher",
		frame_size = {12, 12},
		type       = .Anim,
		num_frames = FLASHER_FRAMES[:],
		frame_t    = 120,
	})
	engine.register_sprite_metadata("patroller", {
		filename   = "patroller",
		frame_size = {16, 16},
		type       = .Tagged,
		tags       = PATROLLER_TAGS[:],
		num_frames = PATROLLER_FRAMES[:],
		frame_t    = 300,
	})
}

// The patroller sheet's body color, replaced for palette-swapped copies.
PATROLLER_BODY :: rl.SKYBLUE

// A walking character that bobs in place and faces where it's going.
character_sprite :: proc(body := PATROLLER_BODY) -> engine.Sprite_State {
	palette: engine.Palette_Swap
	if body != PATROLLER_BODY {
		palette = make(engine.Palette_Swap, 1, context.temp_allocator)
		palette[0] = {PATROLLER_BODY, body}
	}
	return engine.create_sprite_state("patroller", palette = palette, play = true, follow_facing = true)
}

// A sprite whose white art is colored by `tint`.
tinted_sprite :: proc(name: engine.Sprite_Name, tint: rl.Color, play := false, layer: i32 = 0) -> engine.Sprite_State {
	s := engine.create_sprite_state(name, play = play, layer = layer)
	s.tint = tint
	return s
}
