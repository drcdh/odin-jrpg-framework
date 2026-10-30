package game

import rl "vendor:raylib"

@(private = "file") dialogue_icon:    Sprite_State
@(private = "file") select_tile:      Sprite_State
@(private = "file") select_tile_down: Sprite_State
@(private = "file") menu_icon:        Sprite_State

@(private)
ui_init :: proc() {
	if !rl.IsWindowReady() do return
	font_init()
	panes_init()
	dialogue_icon    = ui_icon_state(.Dialogue_Icon_Small)
	select_tile      = ui_icon_state(.Select_Tile)
	select_tile_down = ui_icon_state(.Select_Tile_Down)
	menu_icon        = ui_icon_state(.Select_Icon_Small)
	start_menu_load()
	world_menu_load()
	battle_menu_load()
}

@(private)
ui_destroy :: proc() {
	start_menu_unload()
	world_menu_unload()
	battle_menu_unload()
	font_destroy()
	panes_destroy()
}

@(private)
ui_update :: proc(dt: f32) {
	update_sprite(dt, &dialogue_icon)
	update_sprite(dt, &select_tile)
	update_sprite(dt, &select_tile_down)
	update_sprite(dt, &menu_icon)
}

// Icons draw in screen space from their top-left corner
@(private = "file")
ui_icon_state :: proc(name: Sprite_Name) -> Sprite_State {
	s := create_sprite_state(name, play = true)
	s.origin = {0, 0}
	return s
}

draw_dialogue_icon :: proc(p: [2]f32) {
	draw_sprite(dialogue_icon, p)
}

// The menu cursor, just left of (x, y) in screen pixels
draw_text_indicator_Pixels :: proc(x, y: f32, tint := rl.WHITE) {
	draw_sprite(menu_icon, {x - sprite_size(Sprite_Name.Select_Icon_Small).x, y}, tint)
}

draw_text_indicator_Pixel_Coord :: proc(p: [2]f32, tint := rl.WHITE) {
	draw_text_indicator_Pixels(p.x, p.y, tint)
}

draw_text_indicator :: proc {
	draw_text_indicator_Pixels,
	draw_text_indicator_Pixel_Coord,
}

Tile_Indicator_Direction :: enum {
	Right,
	Down,
}

// A tile-selection arrow beside (x, y) in screen pixels: to its left pointing
// right, or above it pointing down.
draw_tile_indicator_Pixels :: proc(x, y: f32, direction := Tile_Indicator_Direction.Right, tint := rl.WHITE) {
	switch direction {
	case .Right:
		draw_sprite(select_tile, {x - sprite_size(Sprite_Name.Select_Tile).x, y}, tint)
	case .Down:
		draw_sprite(select_tile_down, {x, y - sprite_size(Sprite_Name.Select_Tile_Down).y}, tint)
	}
}

draw_tile_indicator_Pixel_Coord :: proc(p: [2]f32, direction := Tile_Indicator_Direction.Right, tint := rl.WHITE) {
	draw_tile_indicator_Pixels(p.x, p.y, direction, tint)
}

draw_tile_indicator_Tile :: proc(tile: Tile, direction := Tile_Indicator_Direction.Right, tint := rl.WHITE) {
	p := tile_to_pixel(tile)
	draw_tile_indicator_Pixel_Coord(p, direction, tint)
}

draw_tile_indicator :: proc {
	draw_tile_indicator_Pixels,
	draw_tile_indicator_Pixel_Coord,
	draw_tile_indicator_Tile,
}
