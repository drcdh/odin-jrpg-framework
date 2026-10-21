package engine

import "core:slice"
import rl "vendor:raylib"

@(private = "file")
FONT_ATLAS_DATA :: #load("../../assets/textures/font.png")

// @(private = "file")
font: rl.Font

init_font :: proc() {
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

	font = {
		baseSize     = 8,
		glyphCount   = i32(num_glyphs),
		glyphPadding = 0,
		texture      = font_atlas,
		recs         = raw_data(font_rects),
		glyphs       = raw_data(glyphs),
	}
}

delete_font :: proc() {
	delete(slice.from_ptr(font.glyphs, int(font.glyphCount)))
	delete(slice.from_ptr(font.recs, int(font.glyphCount)))
}
