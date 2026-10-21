#+private file
package engine

import rl "vendor:raylib"

PANE_BACKGROUND_COLOR :: rl.Color{1, 87, 155, 255}

PANE_IMAGE_DATA :: #load("../../assets/textures/pane.png")

PANE_PIECE_SIZE :: 8

Pane_Piece :: enum {
	Top_Left,
	Top,
	Top_Right,
	Left,
	Right,
	Bottom_Left,
	Bottom,
	Bottom_Right,
}

pane_texture: rl.Texture

@(private)
init_panes :: proc() {
	pane_image := rl.LoadImageFromMemory(".png", raw_data(PANE_IMAGE_DATA), i32(len(PANE_IMAGE_DATA)))
	pane_texture = rl.LoadTextureFromImage(pane_image)
	rl.UnloadImage(pane_image)
}

draw_pane_piece :: proc(piece: Pane_Piece, l, t: f32) {
	src := rl.Rectangle{0, 0, PANE_PIECE_SIZE, PANE_PIECE_SIZE}
	switch piece {
	case .Top_Left:
	case .Top:
		src.x = PANE_PIECE_SIZE
	case .Top_Right:
		src.x = 2 * PANE_PIECE_SIZE
	case .Left:
		src.y = PANE_PIECE_SIZE
	case .Right:
		src.x = 2 * PANE_PIECE_SIZE
		src.y = PANE_PIECE_SIZE
	case .Bottom_Left:
		src.y = 2 * PANE_PIECE_SIZE
	case .Bottom:
		src.x = PANE_PIECE_SIZE
		src.y = 2 * PANE_PIECE_SIZE
	case .Bottom_Right:
		src.x = 2 * PANE_PIECE_SIZE
		src.y = 2 * PANE_PIECE_SIZE
	}
	draw_texture(pane_texture, src, tile_to_pixel(l, t))
}

draw_pane_f32 :: proc(l, t, w, h: f32) {
	inside_pos := tile_to_pixel(l + .5, t + .5)
	inside_dim := tile_to_pixel(w - 1, h - 1)
	if inside_dim.x > 0 && inside_dim.y > 0 {
		rl.DrawRectangleV(inside_pos, inside_dim, PANE_BACKGROUND_COLOR)
	}
	r := l + w - .5
	b := t + h - .5
	draw_pane_piece(.Top_Left, l, t)
	draw_pane_piece(.Top_Right, r, t)
	draw_pane_piece(.Bottom_Left, l, b)
	draw_pane_piece(.Bottom_Right, r, b)
	for x := l + .5; x < r; x += .5 {
		draw_pane_piece(.Top, x, t)
		draw_pane_piece(.Bottom, x, b)
	}
	for y := t + .5; y < b; y += .5 {
		draw_pane_piece(.Left, l, y)
		draw_pane_piece(.Right, r, y)
	}
}

draw_pane_Tile :: proc(l, t, w, h: i32) {
	draw_pane_f32(f32(l), f32(t), f32(w), f32(h))
}

draw_pane_00_f32 :: proc(w, h: f32) {
	draw_pane_f32(0, 0, w, h)
}

draw_pane_00_Tile_V :: proc(wh: Tile) {
	draw_pane_Tile(0, 0, wh.x, wh.y)
}

draw_pane_00_f32_V :: proc(wh: [2]f32) {
	draw_pane_00_f32(wh.x, wh.y)
}

@(private)
draw_pane :: proc {
	draw_pane_f32,
	draw_pane_Tile,
	draw_pane_00_f32,
	draw_pane_00_f32_V,
	draw_pane_00_Tile_V,
}
