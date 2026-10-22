package engine

import rl "vendor:raylib"

// Bordered UI boxes, drawn from the 3x3 grid of 8 px pieces in pane.png, in
// UI tiles (see text.odin). Screen space.

LABEL_COLOR :: rl.Color{0, 200, 200, 255}

PANE_BACKGROUND_COLOR :: rl.Color{1, 87, 155, 255}

@(private = "file")
PANE_IMAGE_DATA :: #load("../../assets/textures/pane.png")

@(private = "file")
PANE_PIECE_SIZE :: 8

@(private = "file")
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

@(private)
panes_init :: proc() {
	pane_image := rl.LoadImageFromMemory(".png", raw_data(PANE_IMAGE_DATA), i32(len(PANE_IMAGE_DATA)))
	world.ui.pane = rl.LoadTextureFromImage(pane_image)
	rl.UnloadImage(pane_image)
}

@(private)
panes_destroy :: proc() {
	if world.ui.pane.id != 0 do rl.UnloadTexture(world.ui.pane)
	world.ui.pane = {}
}

@(private = "file")
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
	draw_ui_texture(world.ui.pane, src, ui_to_screen(l, t))
}

// A pane at (l, t), w x h UI tiles, in half-tile steps.
draw_pane_f32 :: proc(l, t, w, h: f32) {
	inside_pos := ui_to_screen(l + .5, t + .5)
	inside_dim := [2]f32{w - 1, h - 1} * UI_TILE
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

draw_pane :: proc {
	draw_pane_f32,
	draw_pane_Tile,
	draw_pane_00_f32,
	draw_pane_00_f32_V,
	draw_pane_00_Tile_V,
}
