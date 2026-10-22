package engine

import rl "vendor:raylib"

// UI layout is in tiles of the zoomed screen (UI_TILE pixels), as in the old
// game: a glyph is half a tile square. Negative coordinates count from the
// right or bottom edge of the screen. Screen space: call after EndMode2D.

UI_TILE :: f32(TILE_SIZE * ZOOM)

// The screen's size in UI tiles.
view_tiles :: proc() -> [2]f32 {
	return {VIEW_TILES_W, VIEW_TILES_H}
}

// UI tile coordinates to screen pixels.
ui_to_screen :: proc(l, t: f32) -> [2]f32 {
	p := [2]f32{l, t} * UI_TILE
	if p.x < 0 do p.x += f32(rl.GetScreenWidth())
	if p.y < 0 do p.y += f32(rl.GetScreenHeight())
	return p
}

draw_text_f32 :: proc(l, t: f32, text: cstring, tint := rl.WHITE) {
	rl.DrawTextEx(world.ui.font, text, ui_to_screen(l, t), UI_TILE / 2, 0, tint)
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
	rl.DrawTexturePro(tex, src, {pos.x, pos.y, src.width * ZOOM, src.height * ZOOM}, {}, 0, tint)
}
