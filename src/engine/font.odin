package engine

import "core:slice"
import rl "vendor:raylib"

@(private = "file")
FONT_ATLAS_DATA :: #load("../../assets/textures/font.png")

// The 8x8 bitmap font. `atlas_glyphs` is generated into font_data.odin by
// src/build_tools/generate_font.py. Main thread, with a window.
@(private)
font_init :: proc() {
	font_atlas_image := rl.LoadImageFromMemory(".png", raw_data(FONT_ATLAS_DATA), i32(len(FONT_ATLAS_DATA)))
	font_atlas := rl.LoadTextureFromImage(font_atlas_image)
	rl.UnloadImage(font_atlas_image)

	num_glyphs := len(atlas_glyphs)
	font_rects := make([]rl.Rectangle, num_glyphs)
	glyphs := make([]rl.GlyphInfo, num_glyphs)

	for ag, idx in atlas_glyphs {
		font_rects[idx] = ag.rect
		glyphs[idx] = {
			value    = ag.value,
			offsetX  = i32(ag.offset_x),
			offsetY  = i32(ag.offset_y),
			advanceX = i32(ag.advance_x),
		}
	}

	world.ui.font = {
		baseSize     = 8,
		glyphCount   = i32(num_glyphs),
		glyphPadding = 0,
		texture      = font_atlas,
		recs         = raw_data(font_rects),
		glyphs       = raw_data(glyphs),
	}
}

@(private)
font_destroy :: proc() {
	f := &world.ui.font
	if f.texture.id == 0 do return
	rl.UnloadTexture(f.texture)
	delete(slice.from_ptr(f.glyphs, int(f.glyphCount)))
	delete(slice.from_ptr(f.recs, int(f.glyphCount)))
	f^ = {}
}
