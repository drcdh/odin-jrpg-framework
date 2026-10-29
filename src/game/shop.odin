package game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

Shop :: struct {
	inventory: []Item_Name,
}

Shop_UI_Data :: struct {
	top:        int,
	party_idx:  int,
	slot_idx:   int,
	inv_origin: int,
	inv_row:    int,
}

Shop_UI_State :: enum {
	Inactive,
	Top,
	Buy,
	Sell,
	Swap_Character,
	Swap_Slot,
	Swap_Buy,
}

Shop_Pane :: enum {
	Top,
	Money,
	Inventory,
	Party,
	Equipment,
	Stats,
}

SHOP_NUM_TEXTURES :: len(Shop_Pane)

Shop_Menu_Data :: struct {
	shop:     ^Shop,
	stale:    [SHOP_NUM_TEXTURES]bool,
	textures: [SHOP_NUM_TEXTURES]rl.RenderTexture,
	ui_data:  Shop_UI_Data,
	ui_state: Shop_UI_State,
}

PANE_ORIGIN := [?]Tile{{0, 0}, {11, 0}, {0, 2}, {11, 2}, {11, 2}, {11, 2}}

PANE_DIM := [?]Tile{{11, 2}, {5, 2}, {11, 12}, {5, 12}, {5, 12}, {5, 12}}

SHOP_INVENTORY_ROWS :: 10

shop_menu_data: Shop_Menu_Data

shop_load :: proc() {
	for pane in Shop_Pane {
		dim := PANE_DIM[pane]
		shop_menu_data.textures[pane] = rl.LoadRenderTexture(i32(dim.x) * i32(TILE_SIZE), i32(dim.y) * i32(TILE_SIZE))
	}
}

shop_unload :: proc() {
	for t in shop_menu_data.textures {
		rl.UnloadRenderTexture(t)
	}
}

shop_enter :: proc(shop: ^Shop) {
	shop_menu_data.shop = shop
	shop_menu_data.ui_data = Shop_UI_Data{}
	shop_menu_data.ui_state = .Top

	for pane in Shop_Pane {
		shop_set_stale(pane)
	}
}

shop_exit :: proc() {
	shop_menu_data.shop = nil
	shop_menu_data.ui_state = .Inactive
}

shop_menu_active :: proc() -> bool {
	return shop_menu_data.ui_state != .Inactive
}

shop_draw :: proc() {
	for &stale, i in shop_menu_data.stale {
		if stale {
			shop_redraw_pane(Shop_Pane(i))
			stale = false
		}
	}
	switch shop_menu_data.ui_state {
	case .Inactive:
	case .Top:
		shop_draw_panes(.Top, .Money, .Inventory, .Party)
	case .Buy:
		shop_draw_panes(.Top, .Money, .Inventory, .Party)
	case .Sell:
		shop_draw_panes(.Top, .Money, .Inventory, .Party)
	case .Swap_Character:
		shop_draw_panes(.Top, .Money, .Inventory, .Party)
	case .Swap_Slot:
		shop_draw_panes(.Top, .Money, .Inventory, .Equipment)
	case .Swap_Buy:
		shop_draw_panes(.Top, .Money, .Inventory, .Stats)
	}

	// indicators
	switch shop_menu_data.ui_state {
	case .Inactive:
	case .Top:
		draw_text_indicator(tile_to_pixel(1 + f32(3 * shop_menu_data.ui_data.top), .75))
	case .Buy:
		draw_text_indicator(tile_to_pixel(1, 3 + shop_menu_data.ui_data.inv_row - shop_menu_data.ui_data.inv_origin))
	case .Sell:
		draw_text_indicator(tile_to_pixel(1, 3 + shop_menu_data.ui_data.inv_row - shop_menu_data.ui_data.inv_origin))
	case .Swap_Character:
		draw_tile_indicator(
			tile_to_pixel(
				12 + 2 * f32(shop_menu_data.ui_data.party_idx % 2),
				3 + 2 * int(shop_menu_data.ui_data.party_idx / 2),
			),
		)
	case .Swap_Slot:
		draw_text_indicator(tile_to_pixel(12, 3 + shop_menu_data.ui_data.slot_idx))
	case .Swap_Buy:
		draw_text_indicator(tile_to_pixel(1, 3 + shop_menu_data.ui_data.inv_row - shop_menu_data.ui_data.inv_origin))
	}
}

shop_redraw_top_pane :: proc() {
	draw_text(1, .75, strings.clone_to_cstring("Buy   Sell  Swap", allocator = context.temp_allocator))
}

shop_redraw_money_pane :: proc() {
	s := fmt.ctprint(game_data.money)
	draw_text(f32(4 - len(s) / 2), .75, s)
}

shop_redraw_inventory_pane :: proc() {
	#partial switch shop_menu_data.ui_state {
	case .Top:
		switch shop_menu_data.ui_data.top {
		case 0:
			shop_draw_shop_inventory()
		case 1:
			shop_draw_party_inventory()
		case 2:
			shop_draw_shop_inventory(equipment = true)
		}
	case .Buy:
		shop_draw_shop_inventory()
	case .Sell:
		shop_draw_party_inventory()
	case .Swap_Character:
		shop_draw_shop_inventory(equipment = true)
	case .Swap_Slot:
		shop_draw_shop_inventory(equipment = true, slot = true)
	case .Swap_Buy:
		shop_draw_shop_inventory(equipment = true, slot = true)
	}
}

shop_redraw_party_pane :: proc() {
	p : i32 = 0
	for pc_idx in 0 ..< NUM_PC {
		if game_data.party_membership[pc_idx] {
			origin_tile: Tile = {1, 1} + {2 * (p % 2), 2 * (p / 2)}
			origin := tile_to_pixel(origin_tile)
			draw_sprite(pc_menu_sprite(pc_idx), origin)
			p += 1
		}
	}
}

shop_redraw_equipment_pane :: proc() {
	party_idx := shop_menu_data.ui_data.party_idx
	pc := get_party_member(party_idx)
	for slot_idx in 0 ..< NUM_EQUIPMENT_SLOTS {
		draw_text(1, 1 + f32(slot_idx), equipment_string_short(pc.equipment, Equipment_Slot(slot_idx)))
	}
}

shop_redraw_stats_pane :: proc() {
	party_idx := shop_menu_data.ui_data.party_idx
	item_name :=
		filter_equippables(shop_menu_data.shop.inventory, allocator = context.temp_allocator)[shop_menu_data.ui_data.inv_row]
	slot := Equipment_Slot(shop_menu_data.ui_data.slot_idx)
	pc := get_party_member(party_idx)
	changing_stats := equipped_stats(pc.leveled_stats, changed_equipment(pc.equipment, item_name, slot))
	for s in Stat_Name {
		tint := change_tint(get_stat(pc.stats, s), get_stat(changing_stats, s))
		draw_text(1, 1 + f32(s), stat_string_short(changing_stats, s), tint)
	}
}

shop_redraw_pane :: proc(pane: Shop_Pane) {
	fmt.printfln("Redrawing texture for %w", pane)
	rl.BeginTextureMode(shop_menu_data.textures[pane])
	draw_pane(PANE_DIM[pane])
	switch pane {
	case .Top:
		shop_redraw_top_pane()
	case .Money:
		shop_redraw_money_pane()
	case .Inventory:
		shop_redraw_inventory_pane()
	case .Party:
		shop_redraw_party_pane()
	case .Equipment:
		shop_redraw_equipment_pane()
	case .Stats:
		shop_redraw_stats_pane()
	}
	rl.EndTextureMode()
}

shop_draw_pane :: proc(pane: Shop_Pane) {
	origin_tile := PANE_ORIGIN[pane]
	origin := tile_to_pixel(origin_tile)
	texture := shop_menu_data.textures[pane].texture
	w := f32(texture.width)
	h := f32(texture.height)
	dest := rl.Rectangle{origin.x, origin.y, w, -h}
	rl.DrawTexturePro(texture, {0, 0, w, -h}, dest, {}, 0, rl.WHITE)
}

shop_draw_panes :: proc(panes: ..Shop_Pane) {
	for pane in panes {
		shop_draw_pane(pane)
	}
}

shop_draw_party_inventory :: proc() {
	if shop_menu_data.ui_data.inv_origin > 0 {
		blah := shop_menu_data.ui_data.inv_origin - (len(inventory_order) - SHOP_INVENTORY_ROWS)
		if blah > 0 {
			shop_menu_data.ui_data.inv_origin = max(0, shop_menu_data.ui_data.inv_origin - blah)
		}
	}
	shop_menu_data.ui_data.inv_row = min(len(inventory_order) - 1, shop_menu_data.ui_data.inv_row)
	for r in 0 ..< SHOP_INVENTORY_ROWS {
		if r >= len(inventory_order) {break}
		item_name := inventory_order[r + shop_menu_data.ui_data.inv_origin]
		price, can_sell := item_price(item_name).?
		tint := rl.WHITE if can_sell else rl.GRAY
		draw_text(1, 1 + f32(r), fmt.ctprint(items[item_name].name), tint)
		if can_sell {
			draw_text_rjust(10, 1.5 + f32(r), fmt.ctprintf("%d", get_sell_price(price)), tint)
		}
	}
}

shop_draw_shop_inventory :: proc(equipment := false, slot := false) {
	inventory :=
		filter_equippables(shop_menu_data.shop.inventory, allocator = context.temp_allocator) if equipment else shop_menu_data.shop.inventory
	for r in 0 ..< SHOP_INVENTORY_ROWS {
		if r >= len(inventory) {break}
		item_name := inventory[r + shop_menu_data.ui_data.inv_origin]
		price := item_price(item_name).? or_else 0
		tint := rl.WHITE if !slot || fits_in_slot(item_name, Equipment_Slot(shop_menu_data.ui_data.slot_idx)) else rl.GRAY
		draw_text(1, 1 + f32(r), fmt.ctprint(items[item_name].name), tint)
		draw_text_rjust(10, 1.5 + f32(r), fmt.ctprintf("%d", price), tint)
	}
}

shop_set_stale :: proc(pane: Shop_Pane) {
	shop_menu_data.stale[pane] = true
}

shop_reset_inventory_pos :: proc() {
	shop_menu_data.ui_data.inv_origin = 0
	shop_menu_data.ui_data.inv_row = 0
	shop_set_stale(.Inventory)
}

shop_update :: proc() {
	switch shop_menu_data.ui_state {
	case .Inactive:
	case .Top:
		if get_input(.CANCEL) {
			shop_exit()
		} else if get_input(.ENTER) {
			switch shop_menu_data.ui_data.top {
			case 0:
				shop_menu_data.ui_state = .Buy
			case 1:
				shop_menu_data.ui_state = .Sell
			case 2:
				shop_menu_data.ui_state = .Swap_Character
			}
		} else if dx, ok := get_x_input().?; ok {
			shop_menu_data.ui_data.top = grid_change(shop_menu_data.ui_data.top, dx, 0, 3, 1)
			shop_set_stale(.Inventory)
			shop_reset_inventory_pos()
		}
	case .Buy:
		if get_input(.CANCEL) {
			shop_menu_data.ui_state = .Top
		} else if get_input(.ENTER) {
			if try_buy_item(shop_menu_data.shop.inventory[shop_menu_data.ui_data.inv_row]) {
				shop_set_stale(.Inventory)
				shop_set_stale(.Money)
			}
		} else if dy, ok := get_y_input().?; ok {
			shop_menu_data.ui_data.inv_row, shop_menu_data.ui_data.inv_origin = shift_windowed_selection(
				dy,
				shop_menu_data.ui_data.inv_row,
				shop_menu_data.ui_data.inv_origin,
				SHOP_INVENTORY_ROWS,
				len(shop_menu_data.shop.inventory),
			)
			shop_set_stale(.Inventory)
		}
	case .Sell:
		if get_input(.CANCEL) {
			shop_menu_data.ui_state = .Top
		} else if get_input(.ENTER) {
			if try_sell_item(inventory_order[shop_menu_data.ui_data.inv_row]) {
				shop_set_stale(.Inventory)
				shop_set_stale(.Money)
			}
		} else if dy, ok := get_y_input().?; ok {
			shop_menu_data.ui_data.inv_row, shop_menu_data.ui_data.inv_origin = shift_windowed_selection(
				dy,
				shop_menu_data.ui_data.inv_row,
				shop_menu_data.ui_data.inv_origin,
				SHOP_INVENTORY_ROWS,
				len(inventory_order),
			)
			shop_set_stale(.Inventory)
		}
	case .Swap_Character:
		if get_input(.CANCEL) {
			shop_menu_data.ui_state = .Top
		} else if get_input(.ENTER) {
			shop_menu_data.ui_state = .Swap_Slot
			shop_set_stale(.Equipment)
			shop_set_stale(.Inventory)
		} else {
			m := get_menu_input()
			shop_menu_data.ui_data.party_idx = grid_change(shop_menu_data.ui_data.party_idx, m.x, m.y, 2, 3)
		}
	case .Swap_Slot:
		if get_input(.CANCEL) {
			shop_menu_data.ui_state = .Swap_Character
			shop_set_stale(.Inventory)
		} else if get_input(.ENTER) {
			shop_menu_data.ui_state = .Swap_Buy
			shop_set_stale(.Inventory)
			shop_set_stale(.Stats)
		} else if dy, ok := get_y_input().?; ok {
			shop_menu_data.ui_data.slot_idx = grid_change(shop_menu_data.ui_data.slot_idx, dy, 0, NUM_EQUIPMENT_SLOTS, 1)
			shop_set_stale(.Inventory)
		}
	case .Swap_Buy:
		if get_input(.CANCEL) {
			shop_menu_data.ui_state = .Swap_Slot
		} else if get_input(.ENTER) {
			if try_buy_item(
				filter_equippables(shop_menu_data.shop.inventory, allocator = context.temp_allocator)[shop_menu_data.ui_data.inv_row],
				equip = true,
			) {
				shop_set_stale(.Money)
				shop_set_stale(.Stats)
			}
		} else if dy, ok := get_y_input().?; ok {
			shop_menu_data.ui_data.inv_row, shop_menu_data.ui_data.inv_origin = shift_windowed_selection(
				dy,
				shop_menu_data.ui_data.inv_row,
				shop_menu_data.ui_data.inv_origin,
				SHOP_INVENTORY_ROWS,
				len(filter_equippables(shop_menu_data.shop.inventory, allocator = context.temp_allocator)),
			)
			shop_set_stale(.Inventory)
			shop_set_stale(.Stats)
		}
	}
}

try_buy_item :: proc(item_name: Item_Name, equip := false) -> bool {
	if have_money(item_price(item_name)) {
		buy_item(item_name, equip)
		play_sound(.Kaching)
		return true
	} else {
		play_sound(.Blerp)
	}
	return false
}

buy_item :: proc(item_name: Item_Name, equip := false) {
	add_item(item_name)
	dec_money(item_price(item_name).(Money))
	if equip {
		pc := get_party_member(shop_menu_data.ui_data.party_idx)
		character_set_equipped_item(pc, Equipment_Slot(shop_menu_data.ui_data.slot_idx), item_name)
		shop_set_stale(.Party)
		shop_set_stale(.Equipment)
	}
	play_sound(.Kaching)
}

try_sell_item :: proc(item_name: Item_Name) -> bool {
	if v, can_sell := item_price(item_name).?; can_sell {
		remove_item(item_name)
		inc_money(Money(0.25 * f32(v)))
		play_sound(.Kaching)
		return true
	} else {
		play_sound(.Blerp)
	}
	return false
}
