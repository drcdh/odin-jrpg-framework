package game

import rl "vendor:raylib"

draw_text_f32 :: proc(l, t: f32, text: cstring, tint := rl.WHITE) {
	rl.DrawTextEx(game.ui.font, text, tile_to_pixel(l, t), TILE_SIZE / 2, 0, tint)
}

draw_text_V :: proc(lt: [2]f32, text: cstring, tint := rl.WHITE) {
	draw_text_f32(lt.x, lt.y, text, tint)
}

draw_text :: proc {
	draw_text_f32,
	draw_text_V,
}

// `l` is the center of the text.
draw_text_center :: proc(l, t: f32, text: cstring, tint := rl.WHITE) {
	draw_text(l - f32(len(text)) / 4, t, text, tint)
}

// `l` is the right end of the text.
draw_text_rjust :: proc(l, t: f32, text: cstring, tint := rl.WHITE) {
	draw_text(l - f32(len(text)) / 2, t, text, tint)
}

// Draws a texture region at `pos` (screen pixels), scaled up to the zoom.
@(private)
draw_ui_texture :: proc(tex: rl.Texture, src: rl.Rectangle, pos: [2]f32, tint := rl.WHITE) {
	rl.DrawTexturePro(tex, src, {pos.x, pos.y, src.width, src.height}, {}, 0, tint)
}
