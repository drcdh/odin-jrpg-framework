package game

import rl "vendor:raylib"

import "../rules"

// A walking character that bobs in place and faces where it's going.
walker_sprite :: proc(name: Sprite_Name, palette: Palette_Swap = {}, layer: i32 = 0, tag: Sprite_Tag = .Down) -> Sprite_State {
	return create_sprite_state(name, tag, palette = palette, play = true, follow_facing = true, layer = layer)
}

// Man_Ps is a greyscale template: hair, shirt, skin and trousers.
MAN_PS_HAIR     :: rl.Color{238, 238, 238, 255}
MAN_PS_SHIRT    :: rl.Color{221, 221, 221, 255}
MAN_PS_SKIN     :: rl.Color{187, 187, 187, 255}
MAN_PS_TROUSERS :: rl.Color{204, 204, 204, 255}

// Colors for PCs 1.. (PC 0 is Player_World): hair, shirt, skin, trousers.
@(rodata)
PC_PALETTES := [rules.NUM_PC - 1][4]Color_Swap {
	{{MAN_PS_HAIR, {72, 44, 20, 255}},   {MAN_PS_SHIRT, {190, 40, 40, 255}},  {MAN_PS_SKIN, {255, 205, 170, 255}}, {MAN_PS_TROUSERS, {60, 60, 66, 255}}},
	{{MAN_PS_HAIR, {28, 24, 24, 255}},   {MAN_PS_SHIRT, {40, 120, 60, 255}},  {MAN_PS_SKIN, {176, 120, 80, 255}},  {MAN_PS_TROUSERS, {110, 70, 30, 255}}},
	{{MAN_PS_HAIR, {160, 64, 30, 255}},  {MAN_PS_SHIRT, {120, 60, 160, 255}}, {MAN_PS_SKIN, {255, 222, 200, 255}}, {MAN_PS_TROUSERS, {40, 50, 100, 255}}},
	{{MAN_PS_HAIR, {230, 200, 90, 255}}, {MAN_PS_SHIRT, {30, 140, 140, 255}}, {MAN_PS_SKIN, {222, 170, 120, 255}}, {MAN_PS_TROUSERS, {80, 50, 30, 255}}},
	{{MAN_PS_HAIR, {170, 170, 175, 255}}, {MAN_PS_SHIRT, {220, 120, 30, 255}}, {MAN_PS_SKIN, {120, 76, 50, 255}},  {MAN_PS_TROUSERS, {90, 90, 40, 255}}},
}

// A playable character's walking sprite.
pc_sprite :: proc(pc_idx: int, layer: i32 = 0) -> Sprite_State {
	if pc_idx == 0 do return walker_sprite(.Player_World, layer = layer)
	return walker_sprite(.Man_Ps, PC_PALETTES[pc_idx - 1][:], layer)
}

// A playable character's sprite for menus, facing the player: screen space,
// from its top-left corner, scaled to the zoom.
pc_menu_sprite :: proc(pc_idx: int) -> Sprite_State {
	s := pc_sprite(pc_idx)
	s.follow_facing = false
	s.origin = {0, 0}
	s.scale = {ZOOM, ZOOM}
	return s
}
