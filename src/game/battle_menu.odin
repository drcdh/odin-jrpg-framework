package game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

import "../rules"

Battle_UI_Top_Choices :: enum {
	Skill,
	Item,
	Equip,
	Run,
}

Battle_UI_Data :: struct {
	c_idx:     int,
	top:       Battle_UI_Top_Choices,
	skill_sel: Selection,
	inv_sel:   Selection,
	skill:     Skill_Name,
	targets:   Target_Selection,
	show_text: bool,
}

Battle_UI_State :: enum {
	Inactive,
	Idle,
	Top,
	Skills,
	Skill_Target,
	Inventory,
	Item_Target,
	//Equipment, // choose a slot
	//Equipment_Swap // choose an equippable
}

Battle_Pane :: enum {
	Text,
	Baddies,
	Party,
	Top,
	Skills,
	Inventory,
}

BATTLE_PANE_ORIGIN := [BATTLE_MENU_NUM_TEXTURES]Tile {
	{0, 0}, // Text
	{0, VIEW_TILES_H - 4}, // Baddies
	{7, VIEW_TILES_H - 4}, // Party
	{3, VIEW_TILES_H - 4}, // Top
	{0, VIEW_TILES_H - 4}, // Skills
	{0, VIEW_TILES_H - 4}, // Inventory
}

BATTLE_PANE_DIM := [BATTLE_MENU_NUM_TEXTURES]Tile {
	{VIEW_TILES_W, 2}, // Text
	{7, 4}, // Baddies
	{VIEW_TILES_W - 7, 4}, // Party
	{4, 4}, // Top
	{10, BATTLE_MENU_SKILLS_ROWS / 2 + 1}, // Skills
	{10, BATTLE_MENU_INVENTORY_ROWS / 2 + 1}, // Inventory
}

BATTLE_MENU_NUM_TEXTURES :: len(Battle_Pane)

Battle_Menu :: struct {
	stale:         [BATTLE_MENU_NUM_TEXTURES]bool,
	textures:      [BATTLE_MENU_NUM_TEXTURES]rl.RenderTexture,
	using ui_data: Battle_UI_Data,
	ui_state:      Battle_UI_State,
}

BATTLE_MENU_SKILLS_ROWS :: 6
BATTLE_MENU_INVENTORY_ROWS :: 6

battle_menu: Battle_Menu

battle_menu_load :: proc() {
	for pane in Battle_Pane {
		dim := BATTLE_PANE_DIM[pane]
		battle_menu.textures[pane] = rl.LoadRenderTexture(dim.x * TILE_SIZE, dim.y * TILE_SIZE)
	}
}

battle_menu_unload :: proc() {
	for t in battle_menu.textures {
		rl.UnloadRenderTexture(t)
	}
}

battle_menu_start :: proc() {
	battle_menu.ui_data = Battle_UI_Data{}
	battle_menu.ui_state = .Idle

	for pane in Battle_Pane {
		battle_redraw_pane(pane)
	}
}

battle_menu_end :: proc() {
	battle_menu.ui_data = Battle_UI_Data{}
	battle_menu.ui_state = .Inactive
}

battle_menu_draw :: proc() {
	for &stale, i in battle_menu.stale {
		if stale {
			battle_redraw_pane(Battle_Pane(i))
			stale = false
		}
	}
	switch battle_menu.ui_state {
	case .Inactive:
	case .Idle:
		battle_draw_panes(.Baddies, .Party)
	case .Top:
		battle_draw_panes(.Baddies, .Party, .Top)
	case .Skills:
		battle_draw_panes(.Baddies, .Party, .Top, .Skills)
	case .Skill_Target:
		battle_draw_panes(.Baddies, .Party, .Top, .Skills)
	case .Inventory:
		battle_draw_panes(.Baddies, .Party, .Top, .Inventory)
	case .Item_Target:
		battle_draw_panes(.Baddies, .Party, .Top, .Inventory)
	//case .Equipment:
	//case .Equipment_Swap:
	}
	if battle_menu.show_text {
		battle_draw_panes(.Text)
	}
	if battle_menu.ui_state != .Inactive {
		battle_menu_draw_icons()
	}
}

battle_menu_draw_icons :: proc() {
	switch battle_menu.ui_state {
	case .Inactive:
	case .Idle:
	case .Top:
		battle_draw_top_icons()
	case .Skills:
		battle_draw_skills_icons()
	case .Skill_Target:
	case .Inventory:
		battle_draw_inventory_icons()
	case .Item_Target:
	}
}

battle_redraw_top_pane :: proc() {
	draw_text(0.5, 0.5, "Skill", rl.YELLOW if battle_menu.top == Battle_UI_Top_Choices.Skill else rl.WHITE)
	draw_text(0.5, 1.0, "Item ", rl.YELLOW if battle_menu.top == Battle_UI_Top_Choices.Item else rl.WHITE)
	draw_text(0.5, 1.5, "Equip", rl.YELLOW if battle_menu.top == Battle_UI_Top_Choices.Equip else rl.WHITE)
	draw_text(0.5, 2.0, "Run  ", rl.YELLOW if battle_menu.top == Battle_UI_Top_Choices.Run else rl.WHITE)
}

battle_draw_top_icons :: proc() {
	draw_text_indicator(
		ui_tile_to_screen(BATTLE_PANE_ORIGIN[Battle_Pane.Top]) + ui_to_screen(.5, .5 + .5 * f32(battle_menu.top)),
	)
}

battle_redraw_text_pane :: proc(text: Maybe(string) = nil) {
	if s, is_str := text.(string); is_str {
		rl.BeginTextureMode(battle_menu.textures[Battle_Pane.Text])
		rl.ClearBackground(rl.BLANK)
		l := f32(len(s)) / 2 + 1
		draw_pane((VIEW_TILES_W - l) / 2, 0, l, 1.5)
		draw_text_center(VIEW_TILES_W / 2, .5, strings.clone_to_cstring(s, context.temp_allocator))
		battle_menu.show_text = true
		rl.EndTextureMode()
	} else {
		battle_menu.show_text = false
	}
}

battle_redraw_baddies_pane :: proc() {
	row := 0
	for c_idx in rules.battle.baddies {
		c := rules.battle.combatants[c_idx]
		if true {//c.enabled {
			tint := rl.WHITE
			if c.hitpoints <= 0 {tint = rl.RED}
			draw_text(.5, .5 + f32(row) / 2, fmt.ctprintf("%s", rules.battle.combatants[c_idx].character.name), tint)
			row += 1
		}
	}
}

battle_redraw_party_pane :: proc() {
	for i, p in rules.battle.allies {
		c := rules.battle.combatants[i]
		tint := rl.WHITE
		if c.hitpoints <= 0 {
			tint = rl.RED
		} else if f16(c.hitpoints) <= get_stat(c, .Hitpoints) * 0.25 {
			tint = rl.YELLOW
		}
		draw_text(.5, .5 + f32(p) / 2, fmt.ctprint(c.name), tint)
		draw_text_rjust(8.5, .5 + f32(p) / 2, fmt.ctprintf("% 4d", c.hitpoints), tint)
	}
}


battle_redraw_skills_pane :: proc() {
	pc := rules.battle.combatants[battle_menu.c_idx].character
	// fmt.printfln("\n%#v\n", c_skills)
	for r in 0 ..< BATTLE_MENU_SKILLS_ROWS {
		if r >= len(pc.skills) {break}
		cs := pc.skills[r + battle_menu.skill_sel.origin_idx]
		tint := rl.WHITE
		if r == selection_row(battle_menu.skill_sel) {
			tint = rl.YELLOW
		}
		if cs.charge < CHARGE_MAX {
			tint = rl.ColorTint(tint, rl.GRAY)
		}
		draw_text(
			.5,
			.5 + f32(r) * .5,
			fmt.ctprintf("%s % 3.0f", rules.skills[cs.skill].name, 100 * f16(cs.charge) / CHARGE_MAX),
			tint,
		)
	}
}

battle_draw_skills_icons :: proc() {
	draw_text_indicator(
		ui_tile_to_screen(BATTLE_PANE_ORIGIN[Battle_Pane.Skills]) +
		ui_to_screen(.5, .5 + .5 * selection_row_f(battle_menu.skill_sel)),
	)
}

battle_redraw_inventory_pane :: proc() {
	for r in 0 ..< BATTLE_MENU_INVENTORY_ROWS {
		if r >= len(rules.inventory_order) {break}
		draw_text(
			.5,
			.5 + f32(r) * .5,
			strings.clone_to_cstring(
				rules.items[rules.inventory_order[battle_menu.inv_sel.origin_idx + r]].name,
				context.temp_allocator,
			),
			rl.YELLOW if r == selection_row(battle_menu.inv_sel) else rl.WHITE,
		)
	}
}

battle_draw_inventory_icons :: proc() {
	draw_text_indicator(
		ui_tile_to_screen(BATTLE_PANE_ORIGIN[Battle_Pane.Inventory]) +
		ui_to_screen(.5, .5 + .5 * selection_row_f(battle_menu.inv_sel)),
	)
}

battle_redraw_pane :: proc(pane: Battle_Pane) {
	// fmt.printfln("Redrawing texture for %w", pane)
	rl.BeginTextureMode(battle_menu.textures[pane])
	draw_pane(BATTLE_PANE_DIM[pane])
	// battle_pane_redraw_proc[pane]()
	switch pane {
	case .Text:
	// special
	case .Baddies:
		battle_redraw_baddies_pane()
	case .Party:
		battle_redraw_party_pane()
	case .Top:
		battle_redraw_top_pane()
	case .Skills:
		battle_redraw_skills_pane()
	case .Inventory:
		battle_redraw_inventory_pane()
	}
	rl.EndTextureMode()
}

battle_draw_pane :: proc(pane: Battle_Pane) {
	origin_tile := BATTLE_PANE_ORIGIN[pane]
	origin := ui_tile_to_screen(origin_tile)
	texture := battle_menu.textures[pane].texture
	w := f32(texture.width)
	h := f32(texture.height)
	dest := rl.Rectangle{origin.x, origin.y, w, -h}
	rl.DrawTexturePro(texture, {0, 0, w, -h}, dest, {}, 0, rl.WHITE)
}

battle_draw_panes :: proc(panes: ..Battle_Pane) {
	for pane in panes {
		battle_draw_pane(pane)
	}
}

battle_menu_set_stale :: proc(pane: Battle_Pane) {
	battle_menu.stale[pane] = true
}

battle_menu_next_combatant :: proc() {
	if next, ok := rules.get_next_player_controlled_combatant(battle_menu.c_idx).?; ok {
		battle_menu.c_idx = next
		battle_menu.ui_state = .Top
	} else {
		battle_menu.ui_state = .Idle
	}
}

battle_menu_update :: proc() {
	switch battle_menu.ui_state {
	case .Inactive:
	case .Idle:
		battle_menu_next_combatant()
	case .Top:
		if get_input(.ENTER) {
			switch battle_menu.top {
			case .Skill:
				battle_menu.ui_state = .Skills
				battle_menu_set_stale(.Skills)
			case .Item:
				battle_menu.inv_sel = Selection{}
				battle_menu.ui_state = .Inventory
				battle_menu_set_stale(.Inventory)
			case .Equip:
			case .Run:
			}
		} else if get_input(.MENU) {
			battle_menu_next_combatant()
		} else if dy, ok := get_y_input().?; ok {
			battle_menu.top = Battle_UI_Top_Choices(grid_change(int(battle_menu.top), 0, dy, 1, len(Battle_UI_Top_Choices)))
			battle_menu_set_stale(.Top)
		}

	case .Skills:
		if get_input(.ENTER) {
			cs := rules.battle.combatants[battle_menu.c_idx].character.skills[battle_menu.skill_sel.select_idx]
			if cs.charge == CHARGE_MAX {
				battle_menu.skill = cs.skill
				battle_menu.ui_state = .Skill_Target
				battle_menu.targets = default_target_selection(rules.skills[cs.skill].targeting)
			}
		} else if get_input(.CANCEL) {
			battle_menu.ui_state = .Top
		} else if dy, ok := get_y_input().?; ok {
			c_skills := rules.battle.combatants[battle_menu.c_idx].character.skills
			// fmt.printfln("\n%#v\n", c_skills)
			battle_menu.skill_sel = shift_windowed_selection(
				dy,
				battle_menu.skill_sel,
				BATTLE_MENU_SKILLS_ROWS,
				len(c_skills),
			)
			battle_menu_set_stale(.Skills)
		}

	case .Skill_Target:
		if get_input(.ENTER) {
			cs := &rules.battle.combatants[battle_menu.c_idx].character.skills[battle_menu.skill_sel.select_idx]
			cs.charge = 0
			rules.queue_battle_skill(battle_menu.c_idx, battle_menu.targets, cs.skill)
			battle_menu.ui_state = .Idle
		} else if get_input(.CANCEL) {
			battle_menu.ui_state = .Skills
		} else if m := get_menu_input(); m.x != 0 || m.y != 0 {
			battle_menu.targets = target_update(m.x, m.y, battle_menu.targets, rules.skills[battle_menu.skill].targeting)
		}

	case .Inventory:
		if get_input(.ENTER) {
			if consumable, ok := rules.items[rules.inventory_order[battle_menu.inv_sel.select_idx]].data.(Consumable); ok {
				battle_menu.skill = consumable
				battle_menu.ui_state = .Item_Target
				battle_menu.targets = default_target_selection(rules.skills[consumable].targeting)
			}
		} else if get_input(.CANCEL) {
			battle_menu.ui_state = .Top
		} else if dy, ok := get_y_input().?; ok {
			battle_menu.inv_sel = shift_windowed_selection(
				dy,
				battle_menu.inv_sel,
				BATTLE_MENU_INVENTORY_ROWS,
				len(rules.inventory_order),
			)
			battle_menu_set_stale(.Inventory)
		}

	case .Item_Target:
		if get_input(.ENTER) {
			rules.queue_battle_skill(battle_menu.c_idx, battle_menu.targets, battle_menu.skill)
			battle_menu.ui_state = .Idle
		} else if get_input(.CANCEL) {
			battle_menu.ui_state = .Inventory
		} else if m := get_menu_input(); m.x != 0 || m.y != 0 {
			battle_menu.targets = target_update(m.x, m.y, battle_menu.targets, rules.skills[battle_menu.skill].targeting)
		}
	}
}

// /////// //
// HELPERS //
// /////// //

change_ally_selection :: proc(t, d: int) -> int {
	target := t + d
	if target < 0 {target = len(rules.battle.allies) - 1}
	if target >= len(rules.battle.allies) {target = 0}
	return target
}

change_baddy_selection :: proc(t, d: int) -> int {
	initial_target := t
	target := t + d
	for {
		if target < 0 {target = len(rules.battle.baddies) - 1}
		if target >= len(rules.battle.baddies) {target = 0}
		if target == initial_target {break}
		if rules.combatant_alive(rules.battle.combatants[rules.battle.baddies[target]]) {break}
		target += d
	}
	return target
	// targeting_ease = 0
}

select_first_baddy :: proc() -> int {
	return change_baddy_selection(MAX_ENCOUNTER_SIZE, 1)
}

target_update :: proc(dx, dy: int, ts: Target_Selection, tt: Target_Type) -> Target_Selection {
	switch ts in ts {
	case Target_One_Baddy:
		if dy != 0 {
			return Target_One_Baddy{change_baddy_selection(ts.i, dy)}
		} else if dx < 0 && tt != .One_Opponent && tt != .One_Combatant {
			return Target_All_Baddies{ts.i}
		} else if dx > 0 && tt == .One_Combatant {
			return Target_One_Ally{}
		}
	case Target_All_Baddies:
		if dx > 0 && tt != .All_Opponents {
			return Target_One_Baddy{ts.prev}
		}
	case Target_One_Ally:
		if dy != 0 {
			return Target_One_Ally{change_ally_selection(ts.i, dy)}
		} else if dx > 0 && tt != .One_Ally && tt != .One_Combatant {
			return Target_All_Allies{ts.i}
		} else if dx < 0 && tt == .One_Combatant {
			return Target_One_Baddy{}
		}
	case Target_All_Allies:
		if dx < 0 && tt != .All_Allies {
			return Target_One_Ally{ts.prev}
		}
	case Target_All_Combatants:
	// do nothing
	}
	return ts
}

default_target_selection :: proc(tt: Target_Type) -> Target_Selection {
	ts: Target_Selection
	switch tt {
	case .One_Opponent:
		ts = Target_One_Baddy{select_first_baddy()}
	case .Some_Opponents:
		ts = Target_One_Baddy{select_first_baddy()}
	case .All_Opponents:
		ts = Target_All_Baddies{}
	case .One_Combatant:
		ts = Target_One_Baddy{}
	case .One_Ally:
		ts = Target_One_Ally{}
	case .Some_Allies:
		ts = Target_One_Ally{}
	case .All_Allies:
		ts = Target_All_Allies{}
	case .All_Combatants:
		ts = Target_All_Combatants{}
	}
	return ts
}
