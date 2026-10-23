package game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

import "../rules"

// The world menu: the player's menu outside of battle, opened with MENU
// (player.odin). The world pauses while it's open. Each screen is drawn into
// a render texture when it goes stale, so the menu draws nothing headless.

@(private = "file")
World_Menu_UI_Data :: struct {
	top:       int,
	party_idx: int,
	slot_idx:  int,
	equip_sel: Selection,
	skill_sel: Selection,
	inven_sel: Selection,
	save_sel:  Selection,
}

@(private = "file")
World_Menu_UI_State :: enum {
	Inactive,
	Top,
	Party,
	Character,
	Equipment,
	Skills,
	Skill_Target,
	Inventory,
	Item_Target,
	System,
	Save,
}

@(private = "file")
World_Menu_Textures :: enum {
	Top,
	Character,
	Skills,
	Inventory,
	Targeting,
	System,
	Save,
}

@(private = "file")
NUM_TEXTURES :: len(World_Menu_Textures)

@(private = "file")
World_Menu :: struct {
	stale:         [NUM_TEXTURES]bool,
	textures:      [NUM_TEXTURES]rl.RenderTexture,
	using ui_data: World_Menu_UI_Data,
	ui_state:      World_Menu_UI_State,
	was_paused:    bool, // the clock before the menu opened
}

@(private = "file")
EQUIPMENT_ROWS :: 10
@(private = "file")
INVENTORY_ROWS :: 16
@(private = "file")
SKILLS_ROWS :: 8

@(private = "file")
menu: World_Menu

// Called by ui_init (with a window only).
@(private)
world_menu_load :: proc() {
	w, h := i32(WINDOW_WIDTH), i32(WINDOW_HEIGHT)
	menu.textures[World_Menu_Textures.Top] = rl.LoadRenderTexture(w, h)
	menu.textures[World_Menu_Textures.Character] = rl.LoadRenderTexture(w, h)
	menu.textures[World_Menu_Textures.Skills] = rl.LoadRenderTexture(w, h)
	menu.textures[World_Menu_Textures.Inventory] = rl.LoadRenderTexture(w, h)
	menu.textures[World_Menu_Textures.System] = rl.LoadRenderTexture(w, h)
	menu.textures[World_Menu_Textures.Save] = rl.LoadRenderTexture(w, h)

	w, h = i32(16 * UI_TILE), i32(4 * UI_TILE)
	menu.textures[World_Menu_Textures.Targeting] = rl.LoadRenderTexture(w, h)
}

// Called by ui_destroy. Also closes the menu, so the next init starts closed.
@(private)
world_menu_unload :: proc() {
	for t in menu.textures {
		if t.id != 0 do rl.UnloadRenderTexture(t)
	}
	menu = {}
}

// Opens the menu at the top screen and pauses the world. The player opens it
// with MENU (player.odin), but only when free to act.
world_menu_enter :: proc() {
	if world_menu_active() do return
	menu.ui_data = World_Menu_UI_Data{}
	menu.ui_state = .Top
	menu.stale = true
	menu.was_paused = world.clock.paused
	set_paused(true)
}

// Closes the menu and restores the clock.
world_menu_exit :: proc() {
	if !world_menu_active() do return
	menu.ui_state = .Inactive
	set_paused(menu.was_paused)
}

world_menu_active :: proc() -> bool {
	return menu.ui_state != .Inactive
}

// Screen space, after the dialogue box.
draw_world_menu :: proc() {
	if menu.textures[World_Menu_Textures.Top].id == 0 do return
	switch menu.ui_state {
	case .Inactive:
	case .Top:
		draw_textures(.Top)
	case .Party:
		draw_textures(.Top)
	case .Character:
		draw_textures(.Character)
	case .Equipment:
		draw_textures(.Character)
	case .Skills:
		draw_textures(.Skills)
	case .Skill_Target:
		draw_textures(.Skills, .Targeting)
	case .Inventory:
		draw_textures(.Inventory)
	case .Item_Target:
		draw_textures(.Inventory, .Targeting)
	case .System:
		draw_textures(.System)
	case .Save:
		draw_textures(.Save)
	}
}

// Reads the menu's input. Call after dialogue_update.
@(private)
world_menu_update :: proc() {
	#partial switch menu.ui_state {
	case .Inactive:

	case .Top:
		if get_input(.CANCEL) {
			world_menu_exit()
		} else if get_input(.ENTER) {
			switch menu.top {
			case 0:
				menu.ui_state = .Inventory
			case 1:
				menu.ui_state = .Party
			case 2:
				menu.ui_state = .Party
			case 3:
				menu.ui_state = .System
			case 4:
				rules.metadata_load()
				set_stale(.Save)
				menu.ui_state = .Save
			}
		} else if dy, ok := get_y_input().?; ok {
			menu.top = grid_change(menu.top, 0, dy, 1, 5)
		}

	case .Party:
		if get_input(.CANCEL) {
			menu.ui_state = .Top
		} else if get_input(.ENTER) {
			switch menu.top {
			case 2:
				menu.ui_state = .Character
				set_stale(.Character)
			case 1:
				menu.skill_sel = Selection{}
				menu.ui_state = .Skills
				set_stale(.Skills)
			}
		} else if dy, ok := get_y_input().?; ok {
			menu.party_idx += dy
			menu.party_idx %%= rules.party_size()
		}

	case .Character:
		if get_input(.CANCEL) {
			menu.ui_state = .Party
		} else if get_input(.ENTER) {
			menu.equip_sel = Selection{}
			menu.ui_state = .Equipment
			set_stale(.Character)
		} else {
			m := get_menu_input()
			if m.x != 0 {
				menu.party_idx += m.x
				menu.party_idx %%= rules.party_size()
				set_stale(.Character)
			} else if m.y != 0 {
				menu.slot_idx += m.y
				menu.slot_idx %%= rules.NUM_EQUIPMENT_SLOTS
			}
		}

	case .Equipment:
		if get_input(.CANCEL) {
			menu.ui_state = .Character
			set_stale(.Character)
		} else if get_input(.ENTER) {
			equipment_slot := rules.Equipment_Slot(menu.slot_idx)
			item_name := rules.equippables_order[menu.equip_sel.select_idx]
			if rules.fits_in_slot(item_name, equipment_slot) {
				pc := rules.get_party_member(menu.party_idx)
				rules.character_set_equipped_item(pc, equipment_slot, item_name)
				menu.ui_state = .Character
				set_stale(.Top)
				set_stale(.Character)
				set_stale(.Inventory)
			} else {
				fmt.println(item_name, " does not fit in ", equipment_slot)
			}
		} else {
			if dy, ok := get_y_input().?; ok {
				menu.equip_sel = shift_windowed_selection(dy, menu.equip_sel, EQUIPMENT_ROWS, len(rules.equippables_order))
				set_stale(.Character)
			}
		}

	case .Skills:
		if get_input(.CANCEL) {
			menu.ui_state = .Party
		} else if get_input(.ENTER) {
			// TODO
		} else if dx, ok := get_x_input().?; ok {
			menu.party_idx += dx
			menu.party_idx %%= rules.party_size()
			menu.skill_sel = Selection{}
			set_stale(.Skills)
		} else if dy, got_y := get_y_input().?; got_y {
			pc_idx := rules.get_pc_idx(menu.party_idx)
			pc := rules.playable_characters[pc_idx]
			menu.skill_sel = shift_windowed_selection(dy, menu.skill_sel, SKILLS_ROWS, len(pc.skills))
			set_stale(.Skills)
		}

	case .Skill_Target:
	// TODO

	case .Inventory:
		if get_input(.CANCEL) {
			menu.inven_sel = Selection{}
			menu.ui_state = .Top
		} else if get_input(.ENTER) {
			item_name := rules.inventory_order[menu.inven_sel.select_idx]
			if _, consumable := rules.items[item_name].data.(rules.Consumable); consumable {
				menu.ui_state = .Item_Target
			} else {
				fmt.printfln("Item %s isn't a rules.Consumable", rules.items[item_name])
				play_sound(.Blerp)
			}
		} else if dy, ok := get_y_input().?; ok {
			menu.inven_sel = shift_windowed_selection(dy, menu.inven_sel, INVENTORY_ROWS, len(rules.inventory_order))
			set_stale(.Inventory)
		}

	case .Item_Target:
		if get_input(.CANCEL) {
			menu.ui_state = .Inventory
		} else if get_input(.ENTER) {
			item_name := rules.inventory_order[menu.inven_sel.select_idx]
			party_idx := menu.party_idx
			if consumable, ok := rules.items[item_name].data.(rules.Consumable); ok {
				skill := rules.skills[consumable]
				if s, has_sound := skill_sounds[consumable].?; has_sound do play_sound(s)
				pc := rules.get_party_member(party_idx)
				rules.do_skill(nil, pc, skill)
				rules.remove_item(item_name)
				if rules.game_data.inventory[item_name] == 0 {
					menu.ui_state = .Inventory
				}
				set_stale(.Top)
				set_stale(.Inventory)
				set_stale(.Targeting)
				fmt.printfln("Used item %s on %s", item_name, pc.name)
			} else {
				fmt.println("Uh oh! Tried to use non-consumable %s", item_name)
			}
		} else if dx, ok := get_x_input().?; ok {
			menu.party_idx += dx
			menu.party_idx %%= rules.party_size()
		}

	case .System:
		if get_input(.CANCEL) {
			menu.ui_state = .Top
		}

	case .Save:
		if get_input(.CANCEL) {
			menu.ui_state = .Top
			menu.save_sel = Selection{}
		} else if get_input(.ENTER) {
			save_idx := menu.save_sel.select_idx
			if save_idx >= len(rules.metadata) {
				save_game() // new save file
			} else {
				save_game(rules.metadata[save_idx].filepath)
			}
			menu.ui_state = .Top
			menu.save_sel = Selection{}
		} else if dy, ok := get_y_input().?; ok {
			saves := rules.metadata
			menu.save_sel = shift_windowed_selection(dy, menu.save_sel, SAVES_ROWS, len(saves) + 1)
			set_stale(.Save)
		}
	}
}

// ******************************
// ******************************

@(private = "file")
set_stale :: proc(texture: World_Menu_Textures) {
	menu.stale[texture] = true
}

@(private = "file")
draw_textures :: proc(textures: ..World_Menu_Textures) {
	for t in textures {
		draw_texture(t)
	}
}

@(private = "file")
draw_texture :: proc(texture: World_Menu_Textures) {
	switch texture {
	case .Top:
		draw_top()
	case .Character:
		draw_character()
	case .Skills:
		draw_skills()
	case .Inventory:
		draw_inventory()
	case .Targeting:
		draw_targeting()
	case .System:
		draw_system()
	case .Save:
		draw_save()
	}
}

@(private = "file")
draw_top :: proc() {
	t :: World_Menu_Textures.Top
	if menu.stale[t] {
		rl.BeginTextureMode(menu.textures[t])

		draw_pane(0, 0, 10, 14) // party
		rules.party_apply(proc(p, pc_idx: int) {
			origin := [2]f32{1, 1 + 2 * f32(p)}
			pc := rules.playable_characters[pc_idx]
			hp_tint := rl.WHITE
			hp := pc.hitpoints
			max_hp := int(rules.get_stat(pc, .Hitpoints))
			if hp <= 0 {
				hp_tint = rl.RED
			} else if hp <= max_hp / 4 {
				hp_tint = rl.ORANGE
			}
			draw_text(origin + {2, 0}, strings.clone_to_cstring(pc.name, context.temp_allocator))
			draw_text(origin + {2, 1}, "HP", LABEL_COLOR)
			draw_text(origin + {3.5, 1}, fmt.ctprintf("%d/%d", hp, max_hp), hp_tint)
			draw_sprite(pc_menu_sprite(pc_idx), ui_to_screen(origin.x, origin.y))
		})

		draw_pane(11, 0, 5, 6) // top
		draw_text(12, 0.75 + 0, "Items")
		draw_text(12, 0.75 + 1, "Skills")
		draw_text(12, 0.75 + 2, "Status")
		draw_text(12, 0.75 + 3, "System")
		draw_text(12, 0.75 + 4, "Save")

		draw_pane(12, 9, 4, 3) // clock
		draw_text(12.5, 9.5, "Time", LABEL_COLOR)
		draw_text(12.5, 10.0, fmt.ctprintf("% 6d", rules.game_data.time))
		draw_text(12.5, 10.5, "Steps", LABEL_COLOR)
		draw_text(12.5, 11.0, fmt.ctprintf("% 6d", rules.game_data.steps))

		draw_pane(12, 12, 4, 2) // money
		draw_text(12.5, 12.5, "Cash", LABEL_COLOR)
		draw_text(12.5, 13.0, fmt.ctprintf("% 6d", rules.game_data.money))

		rl.EndTextureMode()
		menu.stale[t] = false
	}

	texture := menu.textures[t].texture
	w := f32(texture.width)
	h := f32(texture.height)
	rect := rl.Rectangle{0, 0, w, -h}
	rl.DrawTexturePro(texture, rect, rect, {}, 0, rl.WHITE)

	#partial switch menu.ui_state {
	case .Top:
		draw_text_indicator(ui_to_screen(12, .75 + f32(menu.top)))
	case .Party:
		p := f32(menu.party_idx)
		draw_tile_indicator(ui_to_screen(1, 1 + 2 * p))
	}
}

draw_character :: proc() {
	t :: World_Menu_Textures.Character
	if menu.stale[t] {
		rl.BeginTextureMode(menu.textures[t])

		pc_idx := rules.get_pc_idx(menu.party_idx)
		pc := rules.playable_characters[pc_idx]

		draw_pane(0, 0, 16, 14)
		draw_pane(12, 0, 4, 1.5)
		draw_text(12.5, .5, "Status", LABEL_COLOR)

		draw_sprite(pc_menu_sprite(pc_idx), ui_to_screen(1, 1))

		draw_text(3.5, 2.0, "Level", LABEL_COLOR)
		draw_text(4.0, 2.5, fmt.ctprint(pc.level))
		if exp, ok := pc.exp_to_next.?; ok {
			draw_text(7.5, 2.0, "Next Level", LABEL_COLOR)
			draw_text(8.0, 2.5, fmt.ctprint(exp))
		}

		draw_text(3.5, 3.0, "HP", LABEL_COLOR)
		hp_tint := rl.WHITE
		hp := pc.hitpoints
		max_hp := int(rules.get_stat(pc, .Hitpoints))
		if hp <= 0 {
			hp_tint = rl.RED
		} else if hp <= max_hp / 4 {
			hp_tint = rl.ORANGE
		}
		draw_text(4, 3.5, fmt.ctprintf("%d/%d", hp, max_hp), hp_tint)

		EQ :: [2]f32{1, 5}
		#partial switch menu.ui_state {
		case .Character:
			for s in rules.Equipment_Slot {
				item_name := rules.equipped_item(pc.equipment, s)
				draw_text(EQ.x, EQ.y + f32(s), fmt.ctprintf("%s", s), LABEL_COLOR)
				draw_text(
					EQ.x + .5,
					EQ.y + .5 + f32(s),
					fmt.ctprintf("%s", rules.items[item_name].name if item_name != .None else ""),
				)
			}
		case .Equipment:
			s := rules.Equipment_Slot(menu.slot_idx)
			current_item_name := rules.equipped_item(pc.equipment, s)
			draw_text(EQ.x, EQ.y, fmt.ctprintf("%s", s), LABEL_COLOR)
			draw_text(
				EQ.x + .5,
				EQ.y + .5,
				fmt.ctprintf("%s>", rules.items[current_item_name].name if current_item_name != .None else "empty"),
			)
			for r in 0 ..< EQUIPMENT_ROWS {
				if r >= len(rules.equippables_order) {break}
				item_name := rules.equippables_order[r + menu.equip_sel.origin_idx]
				if item_name == .None {
					draw_text(EQ.x, EQ.y + 2 + .5 * f32(r), "remove", rl.WHITE)
				} else {
					tint := rl.WHITE if rules.fits_in_slot(item_name, s) else rl.GRAY
					draw_text(EQ.x, EQ.y + 2 + .5 * f32(r), fmt.ctprint(rules.items[item_name].name), tint)
				}
			}
		}

		for s in rules.Stat_Name {
			draw_text(9.5, 5 + f32(s), fmt.ctprint(rules.STAT_STRINGS[s]), LABEL_COLOR)
			draw_text(12.0, 5 + f32(s), fmt.ctprintf("% 3.0f", rules.get_stat(pc, s)))
		}

		if menu.ui_state == .Equipment {
			item_name := rules.equippables_order[menu.equip_sel.select_idx]
			slot_idx := menu.slot_idx
			changing_stats := rules.equipped_stats(pc.leveled_stats, rules.changed_equipment(pc.equipment, item_name, slot_idx))
			for s in rules.Stat_Name {
				draw_text(13.5, 5 + f32(s), ">")
				tint := change_tint(rules.get_stat(pc, s), rules.get_stat(changing_stats, s))
				draw_text(14.0, 5 + f32(s), fmt.ctprintf("% 3.0f", rules.get_stat(changing_stats, s)), tint)
			}
		}

		rl.EndTextureMode()
		menu.stale[t] = false
	}

	texture := menu.textures[t].texture
	w := f32(texture.width)
	h := f32(texture.height)
	rect := rl.Rectangle{0, 0, w, -h}
	rl.DrawTexturePro(texture, rect, rect, {}, 0, rl.WHITE)

	#partial switch menu.ui_state {
	case .Character:
		s := f32(menu.slot_idx)
		draw_text_indicator(ui_to_screen(1, 5 + s))
	case .Equipment:
		r := f32(selection_row(menu.equip_sel))
		draw_text_indicator(ui_to_screen(1, 7 + .5 * r))
	}
}

draw_inventory :: proc() {
	t :: World_Menu_Textures.Inventory
	if menu.stale[t] {
		rl.BeginTextureMode(menu.textures[t])

		draw_pane(0, 0, 16, 14)
		draw_pane(10.5, 0, 5.5, 1.5)
		draw_text(11, .5, "Inventory", LABEL_COLOR)

		draw_text(1, 1.5, "Description", LABEL_COLOR)

		origin_idx := menu.inven_sel.origin_idx
		for r in 0 ..< INVENTORY_ROWS {
			if r >= len(rules.inventory_order) {break}
			item_name := rules.inventory_order[r + origin_idx]
			tint := rl.GRAY
			if rules.is_world_consumable(item_name) {tint = rl.WHITE}
			item := rules.items[item_name]
			draw_text(1, 5 + .5 * f32(r), fmt.ctprint(item.name), tint)
			draw_text_rjust(15, 5 + .5 * f32(r), fmt.ctprintf("*% 3d", rules.game_data.inventory[item_name]), tint)
			if r == selection_row(menu.inven_sel) {
				draw_text(1, 2, strings.clone_to_cstring(item.description, context.temp_allocator))
			}
		}

		rl.EndTextureMode()
		menu.stale[t] = false
	}

	texture := menu.textures[t].texture
	w := f32(texture.width)
	h := f32(texture.height)
	rect := rl.Rectangle{0, 0, w, -h}
	rl.DrawTexturePro(texture, rect, rect, {}, 0, rl.WHITE)

	r := f32(selection_row(menu.inven_sel))
	draw_text_indicator(ui_to_screen(1, 5 + .5 * r))
}

draw_skills :: proc() {
	t :: World_Menu_Textures.Skills
	if menu.stale[t] {
		rl.BeginTextureMode(menu.textures[t])

		pc_idx := rules.get_pc_idx(menu.party_idx)
		pc := rules.playable_characters[pc_idx]

		draw_pane(0, 0, 16, 14)
		draw_pane(12, 0, 4, 1.5)
		draw_text(12.5, .5, "Skills", LABEL_COLOR)

		draw_sprite(pc_menu_sprite(pc_idx), ui_to_screen(1, 1))
		draw_text(3, 1, strings.clone_to_cstring(pc.name, context.temp_allocator))

		draw_text(1, 3, "Description", LABEL_COLOR)

		origin_idx := menu.skill_sel.origin_idx
		for r in 0 ..< SKILLS_ROWS {
			if r >= len(pc.skills) {break}
			cs := pc.skills[r + origin_idx]
			k := cs.skill
			draw_text(1, 5 + .5 * f32(r), fmt.ctprintf("%-12s % 3.0f", rules.skills[k].name, 100 * f16(cs.charge) / rules.CHARGE_MAX))
			// draw_text(1, 1 + f32(r), fmt.ctprint(rules.skills[k].name))
			if r + origin_idx == selection_row(menu.skill_sel) {
				draw_text(1, 3.5, strings.clone_to_cstring(rules.skills[k].description, context.temp_allocator))
			}
		}

		rl.EndTextureMode()
		menu.stale[t] = false
	}

	texture := menu.textures[t].texture
	w := f32(texture.width)
	h := f32(texture.height)
	rect := rl.Rectangle{0, 0, w, -h}
	rl.DrawTexturePro(texture, rect, rect, {}, 0, rl.WHITE)

	r := f32(selection_row(menu.skill_sel))
	draw_text_indicator(ui_to_screen(1, 5 + .5 * r))
}

draw_system :: proc() {
	t :: World_Menu_Textures.System
	if menu.stale[t] {
		rl.BeginTextureMode(menu.textures[t])

		draw_pane(0, 0, 16, 14)
		draw_pane(12, 0, 4, 1.5)
		draw_text(12.5, .5, "System", LABEL_COLOR)

		rl.EndTextureMode()
		menu.stale[t] = false
	}

	texture := menu.textures[t].texture
	w := f32(texture.width)
	h := f32(texture.height)
	rect := rl.Rectangle{0, 0, w, -h}
	rl.DrawTexturePro(texture, rect, rect, {}, 0, rl.WHITE)
}

draw_targeting :: proc() {
	t :: World_Menu_Textures.Targeting
	if menu.stale[t] {
		rl.BeginTextureMode(menu.textures[t])

		draw_pane(0, 0, 16, 4)
		rules.party_apply(
			proc(i, pc_idx: int) {
				pc := rules.playable_characters[pc_idx]
				draw_sprite(pc_menu_sprite(pc_idx), ui_to_screen(1.5 + 2.5 * f32(i), 1))
				hp_tint := rl.WHITE
				hp := pc.hitpoints
				max_hp := int(rules.get_stat(pc, .Hitpoints))
				if hp <= 0 {
					hp_tint = rl.RED
				} else if hp <= max_hp / 4 {
					hp_tint = rl.ORANGE
				} else if hp == max_hp {
					hp_tint = rl.GREEN
				}
				draw_text(.5 + 2.5 * f32(i), 3, fmt.ctprintf("% 4d", pc.hitpoints), hp_tint)
				// draw_text(1 + 3 * f32(i), 3.5, fmt.ctprintf("/% 4.0f", rules.get_stat(pc, .Hitpoints)))
			},
		)

		rl.EndTextureMode()
		menu.stale[t] = false
	}

	texture := menu.textures[t].texture
	w := f32(texture.width)
	h := f32(texture.height)
	src := rl.Rectangle{0, 0, w, -h}
	dest := rl.Rectangle{0, 10 * UI_TILE, w, -h}
	rl.DrawTexturePro(texture, src, dest, {}, 0, rl.WHITE)

	p := f32(menu.party_idx)
	draw_tile_indicator(ui_to_screen(1.5 + 2.5 * p, 11), direction = Tile_Indicator_Direction.Down)
}

draw_save :: proc() {
	t :: World_Menu_Textures.Save
	if menu.stale[t] {
		rl.BeginTextureMode(menu.textures[t])
		draw_pane(0, 0, 16, TITLE_HEIGHT)
		draw_text(8, .5, "Save", LABEL_COLOR)
		for r in 0 ..< SAVES_ROWS {
			if r <= len(rules.metadata) {
				draw_pane(0, f32(TITLE_HEIGHT + r * SLOT_HEIGHT), 16, SLOT_HEIGHT)
				save_idx := r + menu.save_sel.origin_idx
				if save_idx < len(rules.metadata) {
					draw_metadata(save_idx, r)
				} else {
					draw_text(1, f32(TITLE_HEIGHT + r * SLOT_HEIGHT) + .5, "New Save")
				}
			}
		}
		rl.EndTextureMode()
		menu.stale[t] = false
	}

	texture := menu.textures[t].texture
	w := f32(texture.width)
	h := f32(texture.height)
	rect := rl.Rectangle{0, 0, w, -h}
	rl.DrawTexturePro(texture, rect, rect, {}, 0, rl.WHITE)

	r := f32(selection_row(menu.save_sel))
	draw_text_indicator(ui_to_screen(1, TITLE_HEIGHT + r * SLOT_HEIGHT + .5))
}

@(private)
world_menu_clock_update :: proc() {
	// this is just to be called when rules.game_data.time is updated
	set_stale(.Top)
}

// Green if a stat would go up, red if down.
@(private = "file")
change_tint :: proc(prev, next: rules.Stat) -> (tint := rl.WHITE) {
	if next > prev do tint = rl.GREEN
	if next < prev do tint = rl.RED
	return
}
