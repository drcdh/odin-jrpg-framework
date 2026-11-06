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

damage_letters = ["0123456789MiEvaIneResCur "]
assert(len(damage_letters) == len(set(damage_letters)))

status_icons = [
	"kBCcHMOP",
	"pRGsSWZ ",
]
assert(len(status_icons) == len(set(status_icons)))

out_f = open(f"{DEST}/font_data.odin", "w")
out_f.write(f"""package game

import rl "vendor:raylib"

FONT_LETTERS :: "{''.join(letters)}"
DAMAGE_FONT_LETTERS :: "{''.join(damage_letters)}"
STATUS_ICONS :: "{''.join(status_icons)}"

Atlas_Glyph :: struct {{
	rect: rl.Rectangle,
	value: rune,
	offset_x: int,
	offset_y: int,
	advance_x: int,
}}

""")


out_f.write("atlas_glyphs: []Atlas_Glyph = {\n")

for r, row in enumerate(letters):
	y = r*TILE_SIZE
	for c, l in enumerate(row):
		x = c*TILE_SIZE
		if l == "'":
			l = "\\'"
		out_f.write(f"""\t{{ rect = {{{x}, {y}, {TILE_SIZE}, {TILE_SIZE} }}, value = '{l}'}},\n""")
out_f.write("}\n\n")

out_f.write("damage_atlas_glyphs: []Atlas_Glyph = {\n")

for r, row in enumerate(damage_letters):
	y = r*TILE_SIZE
	for c, l in enumerate(row):
		x = c*TILE_SIZE
		if l == "'":
			l = "\\'"
		out_f.write(f"""\t{{ rect = {{{x}, {y}, {TILE_SIZE}, {TILE_SIZE} }}, value = '{l}'}},\n""")
out_f.write("}\n\n")

out_f.write("status_atlas_glyphs: []Atlas_Glyph = {\n")

for r, row in enumerate(status_icons):
	y = r*TILE_SIZE
	for c, l in enumerate(row):
		x = c*TILE_SIZE
		if l == "'":
			l = "\\'"
		out_f.write(f"""\t{{ rect = {{{x}, {y}, {TILE_SIZE}, {TILE_SIZE} }}, value = '{l}'}},\n""")
out_f.write("}")

out_f.close()
