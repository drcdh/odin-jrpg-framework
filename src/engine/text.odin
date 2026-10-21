package engine

import "core:slice"
import rl "vendor:raylib"

draw_text_f32 :: proc(l, t: f32, text: cstring, tint := rl.WHITE) {
	x := l * tile_size
	y := t * tile_size
	if x < 0 {x += view_dim.x}
	if y < 0 {y += view_dim.y}
	rl.DrawTextEx(font, text, {x, y}, tile_size / 2, 0, tint)
}

draw_text_center :: proc(l, t: f32, text: cstring, tint := rl.WHITE) {
	draw_text(l - f32(len(text)) / 4, t, text, tint)
}

draw_text_rjust :: proc(l, t: f32, text: cstring, tint := rl.WHITE) {
	draw_text(l - f32(len(text)) / 2, t, text, tint)
}

draw_text_V :: proc(t: Tile_Offset, text: cstring, tint := rl.WHITE) {
	draw_text(t.x, t.y, text, tint)
}

draw_text :: proc {
	draw_text_f32,
	draw_text_V,
}
