package game

import rl "vendor:raylib"

import "../rules"

// A walking character that faces where it's going and, by default, takes one
// stride per tile only while it moves (Anim_When.Moving).
walker_sprite :: proc(name: Sprite_Name, palette: Palette_Swap = {}, layer: i32 = 0, tag: Sprite_Tag = .Down, anim_when := Anim_When.Moving) -> Sprite_State {
	return create_sprite_state(name, tag, palette = palette, play = true, follow_facing = true, layer = layer, anim_when = anim_when)
}

// Man_Ps and Man_Battle_Ps are greyscale templates that share these colors
// for hair, shirt, skin and trousers.
TEMPLATE_HAIR     :: rl.Color{238, 238, 238, 255}
TEMPLATE_SHIRT    :: rl.Color{221, 221, 221, 255}
TEMPLATE_SKIN     :: rl.Color{187, 187, 187, 255}
TEMPLATE_TROUSERS :: rl.Color{204, 204, 204, 255}

// Colors for PCs 1.. (PC 0 has its own sprites): hair, shirt, skin, trousers.
@(rodata)
PC_PALETTES := [rules.NUM_PC - 1][4]Color_Swap {
	{{TEMPLATE_HAIR, {72, 44, 20, 255}},   {TEMPLATE_SHIRT, {190, 40, 40, 255}},  {TEMPLATE_SKIN, {255, 205, 170, 255}}, {TEMPLATE_TROUSERS, {60, 60, 66, 255}}},
	{{TEMPLATE_HAIR, {28, 24, 24, 255}},   {TEMPLATE_SHIRT, {40, 120, 60, 255}},  {TEMPLATE_SKIN, {176, 120, 80, 255}},  {TEMPLATE_TROUSERS, {110, 70, 30, 255}}},
	{{TEMPLATE_HAIR, {160, 64, 30, 255}},  {TEMPLATE_SHIRT, {120, 60, 160, 255}}, {TEMPLATE_SKIN, {255, 222, 200, 255}}, {TEMPLATE_TROUSERS, {40, 50, 100, 255}}},
	{{TEMPLATE_HAIR, {230, 200, 90, 255}}, {TEMPLATE_SHIRT, {30, 140, 140, 255}}, {TEMPLATE_SKIN, {222, 170, 120, 255}}, {TEMPLATE_TROUSERS, {80, 50, 30, 255}}},
	{{TEMPLATE_HAIR, {170, 170, 175, 255}}, {TEMPLATE_SHIRT, {220, 120, 30, 255}}, {TEMPLATE_SKIN, {120, 76, 50, 255}},  {TEMPLATE_TROUSERS, {90, 90, 40, 255}}},
}

// A playable character's walking sprite.
pc_sprite :: proc(pc_idx: int, layer: i32 = 0) -> Sprite_State {
	if pc_idx == 0 do return walker_sprite(.Player_World, layer = layer)
	return walker_sprite(.Man_Ps, PC_PALETTES[pc_idx - 1][:], layer)
}

// A playable character's battle sprite, idling.
pc_battle_sprite :: proc(pc_idx: int, layer: i32 = 0) -> Sprite_State {
	if pc_idx == 0 do return create_sprite_state(.Player_Battle, Sprite_Tag.Idle, play = true, layer = layer)
	return create_sprite_state(.Man_Battle_Ps, Sprite_Tag.Idle, PC_PALETTES[pc_idx - 1][:], play = true, layer = layer)
}

// A playable character's sprite for menus (its battle sprite): screen space,
// from its top-left corner, scaled to the zoom.
pc_menu_sprite :: proc(pc_idx: int) -> Sprite_State {
	s := pc_battle_sprite(pc_idx)
	s.origin = {0, 0}
	s.scale = {ZOOM, ZOOM}
	return s
}
