#+private file
package game

import rl "vendor:raylib"

Start_Menu_UI_Data :: struct {
	fade_t:   f32,
	start_t:  f32,
	top_idx:  int,
	load_sel: Selection,
}

Start_Menu_UI_State :: enum {
	Inactive,
	Fade_In,
	Start,
	Top,
	Load,
	Working, // starting a new or saved game and fading the screen, not taking user input
}

Start_Menu_Pane :: enum {
	Top,
	Load,
}

START_MENU_NUM_PANES :: len(Start_Menu_Pane)

Start_Menu :: struct {
	stale:         [START_MENU_NUM_PANES]bool,
	textures:      [START_MENU_NUM_PANES]rl.RenderTexture,
	using ui_data: Start_Menu_UI_Data,
	ui_state:      Start_Menu_UI_State,
}

@(rodata)
START_MENU_PANE_ORIGINS := [START_MENU_NUM_PANES]Tile {
	{6, 10}, // Top
	{0, 0}, // Load
}

@(rodata)
START_MENU_PANE_DIM := [START_MENU_NUM_PANES]Tile {
	{4, 3}, // Top
	{16, 14}, // Load
}

start_menu: Start_Menu

@(private)
start_menu_load :: proc() {
	for pane in Start_Menu_Pane {
		dim := START_MENU_PANE_DIM[pane]
		start_menu.textures[pane] = rl.LoadRenderTexture(i32(dim.x * TILE_SIZE), i32(dim.y * TILE_SIZE))
	}
}

@(private)
start_menu_unload :: proc() {
	for t in start_menu.textures {
		rl.UnloadRenderTexture(t)
	}
}

@(private)
start_menu_enter :: proc() {
	start_menu.ui_data = Start_Menu_UI_Data{}
	start_menu.ui_state = .Fade_In
	start_menu_set_stale(.Top)
	metadata_load()
	// set_curtain(1)
}

@(private)
start_menu_exit :: proc() {
	start_menu.ui_state = .Inactive
}

@(private)
start_menu_active :: proc() -> bool {
	return start_menu.ui_state != .Inactive
}

start_menu_set_stale :: proc(pane: Start_Menu_Pane) {
	start_menu.stale[pane] = true
}

@(private)
start_menu_draw :: proc() {
	for &stale, i in start_menu.stale {
		if stale {
			start_menu_redraw_pane(Start_Menu_Pane(i))
			stale = false
		}
	}

	switch start_menu.ui_state {
	case .Inactive:
	case .Fade_In:
		start_menu_draw_title()
	case .Start:
		start_menu_draw_title()
	case .Top:
		start_menu_draw_title()
		start_menu_draw_panes(.Top)
	case .Load:
		start_menu_draw_panes(.Load)
	case .Working:
		start_menu_draw_title()
	}

	switch start_menu.ui_state {
	case .Inactive:
	case .Fade_In:
	case .Start:
	case .Top:
		origin := tile_to_pixel(START_MENU_PANE_ORIGINS[Start_Menu_Pane.Top])
		draw_text_indicator(tile_to_pixel(1, .5 * f32(1 + start_menu.top_idx)) + origin)
	case .Load:
		r := f32(selection_row(start_menu.load_sel))
		draw_text_indicator(tile_to_pixel(1, TITLE_HEIGHT + r * SLOT_HEIGHT + .5))
	case .Working:
	}
}

start_menu_redraw_top_pane :: proc() {
	draw_text(1, 0.5, "Load", rl.GRAY if len(metadata) == 0 else rl.WHITE)
	draw_text(1, 1.0, "New")
	draw_text(1, 1.5, "New+", rl.GRAY)
	draw_text(1, 2.0, "Quit")
}

start_menu_redraw_load_pane :: proc() {
	draw_pane(0, 0, 16, TITLE_HEIGHT)
	draw_text(1, .5, "Load", LABEL_COLOR)
	for r in 0 ..< SAVES_ROWS {
		if r < len(metadata) {
			draw_pane(0, TITLE_HEIGHT + r * SLOT_HEIGHT, 16, SLOT_HEIGHT)
			save_idx := r + start_menu.load_sel.origin_idx
			draw_metadata(save_idx, r)
		}
	}
}

start_menu_redraw_pane :: proc(pane: Start_Menu_Pane) {
	rl.BeginTextureMode(start_menu.textures[pane])
	draw_pane(START_MENU_PANE_DIM[pane])
	switch pane {
	case .Top:
		start_menu_redraw_top_pane()
	case .Load:
		start_menu_redraw_load_pane()
	}
	rl.EndTextureMode()
}

start_menu_draw_pane :: proc(pane: Start_Menu_Pane) {
	origin := tile_to_pixel(START_MENU_PANE_ORIGINS[pane])
	texture := start_menu.textures[pane].texture
	w := f32(texture.width)
	h := f32(texture.height)
	dest := rl.Rectangle{origin.x, origin.y, w, -h}
	rl.DrawTexturePro(texture, {0, 0, w, -h}, dest, {}, 0, rl.WHITE)
}

start_menu_draw_panes :: proc(panes: ..Start_Menu_Pane) {
	for pane in panes {
		start_menu_draw_pane(pane)
	}
}

@(private)
start_menu_update :: proc() {
	switch start_menu.ui_state {
	case .Inactive:

	case .Fade_In:
		start_menu.fade_t += rl.GetFrameTime()
		if get_input(.ENTER) || get_input(.CANCEL) {
			start_menu.ui_state = .Top
		}

	case .Start:
		if get_input(.ENTER) || get_input(.CANCEL) {
			start_menu.ui_state = .Top
		}

	case .Top:
		if get_input(.ENTER) {
			switch start_menu.top_idx {
			case 0: // Load
				if len(metadata) > 0 {
					metadata_load()
					start_menu.ui_state = .Load
					start_menu_set_stale(.Load)
				} else {
					play_sound(.Blerp)
				}
			case 1: // New Game
				start_menu.ui_state = .Working
				start_menu_exit()
				new_game()
				// TODO: this should work when sprites are preloaded or lazy-loaded
				// spawn(proc(_: Entity_Id) {
				// 	fade_screen(1, 1)
				// 	start_menu_exit()
				// 	new_game()
				// })
			case 2: // New Game+
				play_sound(.Blerp)
			case 3:
				game.quitting = true
			}
		} else if dy, ok := get_y_input().?; ok {
			start_menu.top_idx += dy
			start_menu.top_idx %%= 4
		}

	case .Load:
		if get_input(.ENTER) {
			start_menu.ui_state = .Working
			start_menu_exit()
			m := metadata[start_menu.load_sel.select_idx]
			load_save_file(m.filepath)
				// TODO: this should work when sprites are preloaded or lazy-loaded
			// spawn(proc(_: Entity_Id) {
			// 	fade_screen(1, 1)
			// 	start_menu_exit()
			// 	m := metadata[start_menu.load_sel.select_idx]
			// 	load_save_file(m.filepath)
			// })
		} else if get_input(.CANCEL) {
			start_menu.ui_state = .Top
		} else if dy, ok := get_y_input().?; ok {
			start_menu.load_sel = shift_windowed_selection(dy, start_menu.load_sel, SAVES_ROWS, len(metadata))
			start_menu_set_stale(.Load)
		}
	case .Working:
	}
}

start_menu_draw_title :: proc() {
	FADE_IN_T :: 3
	tint := rl.ORANGE
	tint2 := rl.BLUE
	if start_menu.ui_state == .Fade_In {
		if start_menu.fade_t >= FADE_IN_T {
			start_menu.ui_state = .Start
		} else {
			tint.a = u8(255 * start_menu.fade_t / FADE_IN_T)
			tint2.a = u8(255 * start_menu.fade_t / FADE_IN_T)
		}
	}
	rl.DrawTextEx(game.ui.font, SPLASH_TITLE, {1.25 * TILE_SIZE, 3 * TILE_SIZE}, 1.5 * TILE_SIZE, 0, tint)
	rl.DrawTextEx(game.ui.font, SPLASH_TITLE, {1.35 * TILE_SIZE, 3.1 * TILE_SIZE}, 1.5 * TILE_SIZE, 0, tint2)

	if start_menu.ui_state == .Start {
		draw_text(4, 10, "Press Z to Start")
	}
}
