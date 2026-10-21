package engine

import rl "vendor:raylib"

// UI resources: the font, the pane texture and the animated icons. Loaded by
// init when there's a window; without one, text and panes draw nothing.
UI :: struct {
	font:             rl.Font,
	pane:             rl.Texture,
	dialogue_icon:    Sprite_State, // "more text" prompt in the dialogue box
	select_tile:      Sprite_State,
	select_tile_down: Sprite_State,
	menu_icon:        Sprite_State,
}

@(private)
ui_init :: proc() {
	if !rl.IsWindowReady() do return
	font_init()
	panes_init()
	world.ui.dialogue_icon    = ui_icon_state(.Dialogue_Icon_Small)
	world.ui.select_tile      = ui_icon_state(.Select_Tile)
	world.ui.select_tile_down = ui_icon_state(.Select_Tile_Down)
	world.ui.menu_icon        = ui_icon_state(.Select_Icon_Small)
}

@(private)
ui_destroy :: proc() {
	font_destroy()
	panes_destroy()
}

@(private)
ui_update :: proc(dt: f32) {
	update_sprite(dt, &world.ui.dialogue_icon)
	update_sprite(dt, &world.ui.select_tile)
	update_sprite(dt, &world.ui.select_tile_down)
	update_sprite(dt, &world.ui.menu_icon)
}

// Icons draw in screen space from their top-left corner, scaled to the zoom.
@(private = "file")
ui_icon_state :: proc(name: Sprite_Name) -> Sprite_State {
	s := create_sprite_state(name, play = true)
	s.origin = {0, 0}
	s.scale = {ZOOM, ZOOM}
	return s
}

// The menu cursor, just left of (x, y) in screen pixels (ui_to_screen for UI tiles).
draw_text_indicator_Pixels :: proc(x, y: f32, tint := rl.WHITE) {
	draw_sprite(world.ui.menu_icon, {x - sprite_size(Sprite_Name.Select_Icon_Small).x, y}, tint)
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
		draw_sprite(world.ui.select_tile, {x - sprite_size(Sprite_Name.Select_Tile).x, y}, tint)
	case .Down:
		draw_sprite(world.ui.select_tile_down, {x, y - sprite_size(Sprite_Name.Select_Tile_Down).y}, tint)
	}
}

draw_tile_indicator_Pixel_Coord :: proc(p: [2]f32, direction := Tile_Indicator_Direction.Right, tint := rl.WHITE) {
	draw_tile_indicator_Pixels(p.x, p.y, direction, tint)
}

// Beside a world tile, at its on-screen position under the current camera.
draw_tile_indicator_Tile :: proc(tile: Tile, direction := Tile_Indicator_Direction.Right, tint := rl.WHITE) {
	p := rl.GetWorldToScreen2D({f32(tile.x), f32(tile.y)} * TILE_SIZE, world.camera)
	draw_tile_indicator_Pixels(p.x, p.y, direction, tint)
}

draw_tile_indicator :: proc {
	draw_tile_indicator_Pixels,
	draw_tile_indicator_Pixel_Coord,
	draw_tile_indicator_Tile,
}
