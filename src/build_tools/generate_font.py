DEST = "./src/game"
TILE_SIZE = 8

letters = [
	"ABCDEFGHIJKLM ",
	"NOPQRSTUVWXYZ ",
	"abcdefghijklm ",
	"nopqrstuvwxyz ",
	"0123456789@>)}",
	"!?%/'.-|:,+*({",
]

out_f = open(f"{DEST}/font_data.odin", "w")
out_f.write(f"""package game

import rl "vendor:raylib"

LETTERS_IN_FONT :: "{''.join(letters)}"

Atlas_Glyph :: struct {{
	rect: rl.Rectangle,
	value: rune,
	offset_x: int,
	offset_y: int,
	advance_x: int,
}}

atlas_glyphs: []Atlas_Glyph = {{
""")

for r, row in enumerate(letters):
	y = r*TILE_SIZE
	for c, l in enumerate(row):
		x = c*TILE_SIZE
		if l == "'":
			l = "\\'"
		out_f.write(f"""\t{{ rect = {{{x}, {y}, {TILE_SIZE}, {TILE_SIZE} }}, value = '{l}'}},\n""")

out_f.write("}")

out_f.close()
