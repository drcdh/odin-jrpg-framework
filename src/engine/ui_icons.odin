#+private file
package engine

import rl "vendor:raylib"

select_tile_icon: Sprite_State
select_tile_icon_down: Sprite_State
world_menu_icon: Sprite_State

@(private)
init_ui_icons :: proc() {
	select_tile_icon = create_sprite_state(.Select_Tile, play = true)
	select_tile_icon_down = create_sprite_state(.Select_Tile_Down, play = true)
	world_menu_icon = create_sprite_state(.Select_Icon_Small, play = true)
}

@(private)
update_ui_icons :: proc(dt: f32) {
	update_sprite(dt, &select_tile_icon)
	update_sprite(dt, &select_tile_icon_down)
	update_sprite(dt, &world_menu_icon)
}

draw_text_indicator_Pixels :: proc(x, y: f32, tint := rl.WHITE) {
	draw_sprite(world_menu_icon, {x - sprite_size(Sprite_Name.Dialogue_Icon_Small).x, y}, tint)
}

draw_text_indicator_Pixel_Coord :: proc(p: [2]f32, tint := rl.WHITE) {
	draw_text_indicator_Pixels(p.x, p.y, tint)
}

draw_text_indicator_Tile_T :: proc(i, j: i32, tint := rl.WHITE) {
	draw_text_indicator_Pixel_Coord(tile_to_pixel(i, j), tint)
}

draw_text_indicator_Tile_Coord :: proc(tile: Tile, tint := rl.WHITE) {
	draw_text_indicator_Pixel_Coord(tile_to_pixel(tile), tint)
}

@(private)
draw_text_indicator :: proc {
	draw_text_indicator_Pixels,
	draw_text_indicator_Pixel_Coord,
	draw_text_indicator_Tile_T,
	draw_text_indicator_Tile_Coord,
}

@(private)
Tile_Indicator_Direction :: enum {
	Right,
	// Left,
	Down,
}

draw_tile_indicator_Pixels :: proc(x, y: f32, direction := Tile_Indicator_Direction.Right, tint := rl.WHITE) {
	switch direction {
	case .Right:
		draw_sprite(select_tile_icon, {x - sprite_size(Sprite_Name.Select_Tile).x, y}, tint)
	// case .Left:
	// 	draw_sprite(select_tile_icon, {x + sprite_size(Sprite_Name.Select_Tile).x, y}, tint, flip_x=true)
	case .Down:
		draw_sprite(select_tile_icon_down, {x, y - sprite_size(Sprite_Name.Select_Tile_Down).y}, tint)
	}
}

draw_tile_indicator_Pixel_Coord :: proc(
	p: Pixel_Coord,
	direction := Tile_Indicator_Direction.Right,
	tint := rl.WHITE,
) {
	draw_tile_indicator_Pixels(p.x, p.y, direction, tint)
}

draw_tile_indicator_Tile_T :: proc(i, j: i32, direction := Tile_Indicator_Direction.Right, tint := rl.WHITE) {
	draw_tile_indicator_Pixel_Coord(tile_to_pixel(i, j), direction, tint)
}

draw_tile_indicator_Tile_Coord :: proc(
	tile: Tile,
	direction := Tile_Indicator_Direction.Right,
	tint := rl.WHITE,
) {
	draw_tile_indicator_Pixel_Coord(tile_to_pixel(tile), direction, tint)
}

@(private)
draw_tile_indicator :: proc {
	draw_tile_indicator_Pixels,
	draw_tile_indicator_Pixel_Coord,
	draw_tile_indicator_Tile_T,
	draw_tile_indicator_Tile_Coord,
}
