package game

import rl "vendor:raylib"

walker_sprite :: proc(name: Sprite_Name, palette: Palette_Swap = {}, layer: i32 = 0, tag: Sprite_Tag = .Down, anim_when := Anim_When.Moving) -> Sprite_State {
	return create_sprite_state(name, tag, palette = palette, play = true, layer = layer, anim_when = anim_when)
}

// Man_Ps and Man_Battle_Ps are greyscale templates that share these colors
// for hair, shirt, skin and trousers.
TEMPLATE_HAIR     :: rl.Color{238, 238, 238, 255}
TEMPLATE_SHIRT    :: rl.Color{221, 221, 221, 255}
TEMPLATE_SKIN     :: rl.Color{187, 187, 187, 255}
TEMPLATE_TROUSERS :: rl.Color{204, 204, 204, 255}

// Colors for PCs 1.. (PC 0 has its own sprites): hair, shirt, skin, trousers.
@(rodata)
PC_PALETTES := [NUM_PC - 1][4]Color_Swap {
	{{TEMPLATE_HAIR, {72, 44, 20, 255}},   {TEMPLATE_SHIRT, {190, 40, 40, 255}},  {TEMPLATE_SKIN, {255, 205, 170, 255}}, {TEMPLATE_TROUSERS, {60, 60, 66, 255}}},
	{{TEMPLATE_HAIR, {28, 24, 24, 255}},   {TEMPLATE_SHIRT, {40, 120, 60, 255}},  {TEMPLATE_SKIN, {176, 120, 80, 255}},  {TEMPLATE_TROUSERS, {110, 70, 30, 255}}},
	{{TEMPLATE_HAIR, {160, 64, 30, 255}},  {TEMPLATE_SHIRT, {120, 60, 160, 255}}, {TEMPLATE_SKIN, {255, 222, 200, 255}}, {TEMPLATE_TROUSERS, {40, 50, 100, 255}}},
	{{TEMPLATE_HAIR, {230, 200, 90, 255}}, {TEMPLATE_SHIRT, {30, 140, 140, 255}}, {TEMPLATE_SKIN, {222, 170, 120, 255}}, {TEMPLATE_TROUSERS, {80, 50, 30, 255}}},
	{{TEMPLATE_HAIR, {170, 170, 175, 255}}, {TEMPLATE_SHIRT, {220, 120, 30, 255}}, {TEMPLATE_SKIN, {120, 76, 50, 255}},  {TEMPLATE_TROUSERS, {90, 90, 40, 255}}},
}

pc_sprite :: proc(pc_idx: int, layer: i32 = 0) -> Sprite_State {
	if pc_idx == 0 do return walker_sprite(.Player_World, layer = layer)
	return walker_sprite(.Man_Ps, PC_PALETTES[pc_idx - 1][:], layer)
}

pc_battle_sprite :: proc(pc_idx: int, layer: i32 = 0) -> (s: Sprite_State) {
	if pc_idx == 0 {
		s = create_sprite_state(.Player_Battle, .Idle, play = true, layer = layer)
	} else {
		s = create_sprite_state(.Man_Battle_Ps, .Idle, PC_PALETTES[pc_idx - 1][:], play = true, layer = layer)
	}
	return
}

apply_character_look :: proc(s: ^Sprite_State, health: Stat, statuses: Statuses, windup: bool = false) {
	t := Sprite_Tag.Idle
	if windup do t = .Ready
	if health <= 0 {
		t = .Downed
	} else if health <= .25 {
		t = .Kneeled
	}
	if has_status(statuses, .Paralyze) do t = .Kneeled
	if has_status(statuses, .Sleep)    do t = .Downed
	if s.tag != t do set_sprite_tag(s, t)

	s.flip_x = has_status(statuses, .Confuse) || has_status(statuses, .Control)

	tint := rl.WHITE
	if has_status(statuses, .Poison) do tint = rl.LIME
	if has_status(statuses, .Zombie) do tint = rl.GRAY
	s.tint = {tint.r, tint.g, tint.b, s.tint.a} // don't mess with alpha
}

update_character_sprite :: proc(c: Character) {
	e, ok := entity_get(c.eid)
	if !ok do return
	apply_character_look(&e.sprite, Stat(c.hitpoints) / get_stat(c, .Hitpoints), c.statuses, c.windup)
}

// A PC's battle sprite with the given look, for when there's no entity (save
// file previews).
pc_look_sprite :: proc(pc_idx: int, health: Stat, statuses: Statuses) -> Sprite_State {
	s := pc_battle_sprite(pc_idx)
	apply_character_look(&s, health, statuses)
	return s
}

// Draws `s` with its top-left corner at `top_left`, whatever its origin.
draw_sprite_top_left :: proc(s: Sprite_State, top_left: [2]f32) {
	draw_sprite(s, top_left + s.origin * sprite_size(s) * [2]f32{abs(s.scale.x), abs(s.scale.y)})
}

// Draws `c`'s entity sprite with its top-left corner at `top_left` (menus).
draw_character_sprite :: proc(c: Character, top_left: [2]f32) {
	if e, ok := entity_get(c.eid); ok do draw_sprite_top_left(e.sprite, top_left)
}

// Plays `sprite` once over `target`'s tile and waits for it to end.
run_anim :: proc(target: Entity_Id, sprite: Sprite_Name, flip_x := false) -> bool {
	s := create_sprite_state(sprite, play = true, layer = SKILL_ANIM_LAYER, anim_when = .Once_And_Hide)
	s.flip_x = flip_x
	eid := spawn_entity(Entity{name = "animation", sprite = s, ghost = true, battle = true}) // TODO: fmt to make specific Entity name
	if e, ok := entity_get(eid); ok do e.pos = entity_pos(target)
	defer destroy_entity(eid)
	return pause(max(animation_length(s), .25)) // a static sprite still shows a moment
}

