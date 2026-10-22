package game

import rl "vendor:raylib"

import "../rules"

// The patroller sheet's body color, replaced for palette-swapped copies.
PATROLLER_BODY :: rl.SKYBLUE

// White, so script tints (the glider turning the player red) show their true color.
PLAYER_BODY :: rl.WHITE

// A walking character that bobs in place and faces where it's going.
character_sprite :: proc(body := PATROLLER_BODY, layer: i32 = 0) -> Sprite_State {
	palette: Palette_Swap
	if body != PATROLLER_BODY {
		palette = make(Palette_Swap, 1, context.temp_allocator)
		palette[0] = {PATROLLER_BODY, body}
	}
	return create_sprite_state(.Patroller, palette = palette, play = true, follow_facing = true, layer = layer)
}

// Each playable character's body color.
@(rodata)
PC_BODIES := [rules.NUM_PC]rl.Color{PLAYER_BODY, rl.ORANGE, rl.LIME, rl.PINK, rl.GOLD, rl.VIOLET}

// A playable character's sprite for menus: screen space, from its top-left
// corner, scaled to the zoom.
pc_menu_sprite :: proc(pc_idx: int) -> Sprite_State {
	s := character_sprite(PC_BODIES[pc_idx])
	s.follow_facing = false
	s.origin = {0, 0}
	s.scale = {ZOOM, ZOOM}
	return s
}
