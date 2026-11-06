package game

import "core:slice"
import rl "vendor:raylib"

Font :: enum {
	Normal,
	Damage,
	Status,
}

@(private = "file")
FONT_ATLAS_DATA :: #load("../../assets/textures/font.png")

@(private = "file")
DAMAGE_FONT_ATLAS_DATA :: #load("../../assets/textures/font_damage.png")

@(private = "file")
STATUS_ATLAS_DATA :: #load("../../assets/textures/status_icons.png")

@(private)
font: rl.Font

@(private)
damage_font: rl.Font

@(private)
status_font: rl.Font

get_font :: proc(f: Font) -> (rlf: rl.Font) {
	switch f {
	case .Normal: rlf = font
	case .Damage: rlf = damage_font
	case .Status: rlf = status_font
	}
	return
}

@(private = "file")
font_init_ :: proc(raw_data_: [^]u8, length: i32, atlas_glyphs: []Atlas_Glyph, font: ^rl.Font) {
	font_atlas_image := rl.LoadImageFromMemory(".png", raw_data_, length)
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

	font^ = {
		baseSize     = 8,
		glyphCount   = i32(num_glyphs),
		glyphPadding = 0,
		texture      = font_atlas,
		recs         = raw_data(font_rects),
		glyphs       = raw_data(glyphs),
	}
}

@(private)
font_init :: proc() {
	font_init_(raw_data(FONT_ATLAS_DATA), i32(len(FONT_ATLAS_DATA)), atlas_glyphs, &font)
	font_init_(raw_data(DAMAGE_FONT_ATLAS_DATA), i32(len(DAMAGE_FONT_ATLAS_DATA)), damage_atlas_glyphs, &damage_font)
	font_init_(raw_data(STATUS_ATLAS_DATA), i32(len(STATUS_ATLAS_DATA)), status_atlas_glyphs, &status_font)
}

@(private = "file")
font_destroy_ :: proc(font: ^rl.Font) {
	if font.texture.id == 0 do return
	rl.UnloadTexture(font.texture)
	delete(slice.from_ptr(font.glyphs, int(font.glyphCount)))
	delete(slice.from_ptr(font.recs, int(font.glyphCount)))
	font^ = {}
}

@(private)
font_destroy :: proc() {
	font_destroy_(&font)
	font_destroy_(&damage_font)
	font_destroy_(&status_font)
}
