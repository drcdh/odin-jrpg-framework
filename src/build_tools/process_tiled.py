import fnmatch
import os
import pathlib
import subprocess
import xml.etree.ElementTree as ET
import pytiled_parser

from collections import defaultdict

import passable

ROOT = "./assets/tiled"
TILESETS = "./assets/tilesets"
# Level code goes in the game package; the Level and Chest_Datum enums are
# saved game data, so they go in the (headless) rules package.
DEST = "./src/game"
RULES_DEST = "./src/rules"
MAP_MODES = ("DEFAULT", "CLAMP", "WRAP")

def orderedpair_to_tile(c):
	return int(c.x//16), int(c.y//16)

# def tiled_rect_to_rl_rect(obj):
# 	return "{{ {x}, {y}, {w}, {h} }}".format(x=obj.coordinates.x//16, y=obj.coordinates.y//16, w=obj.size.width//16, h=obj.size.height//16)

def _blarg(x0, y0, c):
	x, y = orderedpair_to_tile(c)
	return x0+x, y0+y

def tiled_poly_to_odin_poly(obj):
	x0, y0 = orderedpair_to_tile(obj.coordinates)
	l = len(obj.points)
	return f"[{l}][2]f32{{" + ",".join(["{{ {}, {} }}".format(*_blarg(x0, y0, c)) for c in obj.points]) + "}", l

def is_collectable(obj):
	return obj.name.startswith("CHEST")

def is_path(obj):
	return obj.name != "encounter_region" and (isinstance(obj, pytiled_parser.tiled_object.Polygon) or isinstance(obj, pytiled_parser.tiled_object.Polyline))

chest_data = []
encounter_regions = defaultdict(list)
encounter_sets = []
level_enums = []
referenced_levels = set() # door destinations and sources, which may not have maps yet

# "Level" or "Level/room" (room defaults to main) -> "Level_Room"
def level_ref_to_enum(ref):
	l, _, room = ref.partition("/")
	return f"{l}_{room or 'main'}".title()

def process_tmx(level_name, room_name):
	tmx_file = pathlib.Path(f"{ROOT}/{level_name}/{room_name}.tmx")
	# level_name = f"{level_name.lower()}_{room_name}" if room_name != "main" else level_name.lower()
	# del room_name
	lr_title = f"{level_name}_{room_name}".title()
	lr_lower = lr_title.lower()
	lr_upper = lr_title.upper()
	level_enums.append(lr_title)
	prefix = lr_upper + "_"

	level_filename = f"{DEST}/level_{lr_lower}_data.odin"
	out_f = open(level_filename, "w")

	out_f.write("package game\n")

	item_entities = []
	map_layers = []
	paths = []
	paths_enum = []
	egresses = [] # to other levels/rooms
	entrances = [] # from other levels/rooms

	tmap = pytiled_parser.parse_map(tmx_file)

	tileset_firstgids = tuple((ts.name, ts.firstgid) for ts in tmap.tilesets.values())

	# Custom map properties: where leaving the map edge goes (none if empty),
	# and the Map_Mode.
	edge_level = tmap.properties.get("edge_level", "") if tmap.properties else ""
	map_mode = (tmap.properties.get("map_mode", "") if tmap.properties else "") or "DEFAULT"
	assert map_mode in MAP_MODES, f"{tmx_file}: map_mode must be one of {MAP_MODES}"
	if edge_level:
		edge_level = level_ref_to_enum(edge_level)
		referenced_levels.add(edge_level)

	for layer in tmap.layers:
		if isinstance(layer, pytiled_parser.TileLayer):
			map_layers.append((layer.name, layer.data))
		elif isinstance(layer, pytiled_parser.ObjectLayer):
			for obj in layer.tiled_objects:
				if is_path(obj):
					tile_coords = []
					path = obj.points
					origin = obj.coordinates
					for c in path:
						t = int((c.x + origin.x)//16), int((c.y + origin.y)//16)
						tile_coords.append(t)
					paths.append(tile_coords)
					paths_enum.append(obj.name.title())
				elif isinstance(obj, pytiled_parser.tiled_object.Point):
					if is_collectable(obj):
						item_entities.append(obj)
					elif obj.name.startswith("DOOR"):
						_l = obj.properties.get("level")
						_room = obj.properties.get("room")
						if not _l and not _room:
							_l, _room = "overworld", "main"
						elif not _room:
							_room = "main"
						elif not _l:
							_l = level_name
						door_lr_enum = ".{}_{}".format(_l, _room)
						referenced_levels.add(door_lr_enum[1:].title())
						door_idx = obj.properties["door_idx"]
						pos = orderedpair_to_tile(obj.coordinates)
						if "-IN" not in obj.name:
							egresses.append((door_lr_enum, pos, door_idx, obj.properties["warp"]))
						if "-OUT" not in obj.name:
							entrances.append((door_lr_enum, pos, obj.properties.get("eFace"), obj.properties.get("iFace"), obj.properties["iOffset"], door_idx))
					elif not obj.name.startswith("!"):
						name = obj.name.upper()
						pos = orderedpair_to_tile(obj.coordinates)
						out_f.write(f"{prefix}{name} :: Tile{{ {pos[0]}, {pos[1]} }}\n")
				elif isinstance(obj, pytiled_parser.tiled_object.Polygon):
					if obj.name.startswith("encounter"):
						encounter_regions[lr_title].append((tiled_poly_to_odin_poly(obj), obj.properties["region"]))
						encounter_sets.append(obj.properties["region"])
					else:
						print(f"ignoring Polygon {obj}")
				else:
					print(f"unknown object type {type(obj)}: {obj}")
		else:
			print(f"unknown layer type {type(layer)}: {layer}")

	num_layers = len(map_layers)
	h_tiles = len(map_layers[0][1])
	w_tiles = len(map_layers[0][1][0])

	out_f.write(f"{prefix}WIDTH :: {w_tiles}\n")
	out_f.write(f"{prefix}HEIGHT :: {h_tiles}\n")

	out_f.write("@(rodata)\n")
	out_f.write(f"{prefix}TILESETS := [{len(tileset_firstgids)}]Tileset_Id{{\n")
	for ts, _ in tileset_firstgids:
		out_f.write(f"\t.{ts.title()},\n")
	out_f.write(f"}}\n")

	out_f.write("@(rodata)\n")
	out_f.write(f"{prefix}FIRSTGIDS := [{len(tileset_firstgids)}]int{{\n")
	for _, g in tileset_firstgids:
		out_f.write(f"\t{g},\n")
	out_f.write(f"}}\n")

	out_f.write("@(rodata)\n")
	out_f.write(f"{lr_lower}_map := [{num_layers}][{h_tiles}][{w_tiles}]int{{\n")
	for i, (_, layer_data) in enumerate(map_layers):
		out_f.write(f"{{")
		for row in layer_data:
			out_f.write(f"{{ {str([max(0, r) for r in row])[1:-1]} }},\n")
		out_f.write("},\n")
	out_f.write("}\n")

	# Row-major, for Level_Map.passable.
	flags = [p for row in passable.process(map_layers, tileset_firstgids) for p in row]
	out_f.write("@(rodata)\n")
	out_f.write(f"{prefix}PASSABLE := [{h_tiles * w_tiles}]u8{{ {str(flags)[1:-1]} }}\n")

	out_f.write("@(rodata)\n")
	out_f.write(f"{prefix}ROUTES := [][]Tile{{\n")
	for p in paths:
		out_f.write("{\n")
		for t in p:
			out_f.write(f"{{ {t[0]}, {t[1]} }},\n")
		out_f.write("},\n")
	out_f.write("}\n")

	for i, p in enumerate(paths_enum):
		out_f.write(f"{prefix}{p.upper()} :: {i}\n")
	out_f.write(f"""
render_{lr_lower} :: proc() {{
	begin_map_render()
	for l in 0..<{num_layers} {{
		for j in 0..<{h_tiles} {{
			for i in 0..<{w_tiles} {{
				draw_map_tile({lr_lower}_map[l][j][i], i, j)
			}}
		}}
	}}
	end_map_render()
}}
""")

	out_f.write(f"""tiled_init_{lr_lower} :: proc() {{
	// fmt.println(\"Running tiled_init_{lr_lower}\")
	set_map({{
		size = {{ {prefix}WIDTH, {prefix}HEIGHT }},
		tilesets = {prefix}TILESETS[:],
		firstgids = {prefix}FIRSTGIDS[:],
		routes = {prefix}ROUTES[:],
		passable = {prefix}PASSABLE[:],
		mode = .{map_mode},
		open_edges = {"true" if edge_level else "false"},
	}})
	world.levels.edge = {"." + edge_level if edge_level else "nil"}
	""")
	for n, item_entity in enumerate(item_entities):
		datum = f"{lr_title}_{n}"
		chest_data.append(datum)
		x, y = orderedpair_to_tile(item_entity.coordinates)
		encounter = item_entity.properties["encounter"]
		hidden = item_entity.properties["hidden"]
		items = item_entity.properties["items"]
		items = ", " + ", ".join(["."+_s for _s in items.split(",")]) if items else ""
		# A Box entity; a hidden chest is an invisible ghost on its tile.
		script = f"monster_in_a_box (self, .{datum}, .{encounter}{items})" if encounter else f"items_in_a_box(self, .{datum}{items})"
		opened = f"get_game_data(Chest_Datum.{datum})"
		sprite = "" if hidden else f"\n\t\tsprite = create_sprite_state(.Box, {opened} ? .Opened : .Closed),"
		ghost = "true" if hidden else "false"
		out_f.write(f"""\n\tspawn_entity({{
		name = "chest:{datum}",
		tile = {{ {x}, {y} }},
		ghost = {ghost},{sprite}
		trigger = {opened} ? {{}} : new_trigger(proc(self: Entity_Id) {{
			{script}
		}}, autoface = false),
	}})""")

	# EGRESSES
	# Ghost entities on the door tiles; stepping on one leaves the level.
	# Warp pads show the Warp sprite under whoever stands on them.
	for n, (destination, pos, i, warp) in enumerate(egresses):
		x, y = pos
		proc = f"warp_to_level({destination.title()}, {i})" if warp else f"egress({destination.title()}, {i})"
		sprite = "\n\t\tsprite = create_sprite_state(.Warp, play = true)," if warp else ""
		out_f.write(f"""\n\tspawn_entity({{
		name = "egress:{n}:{destination[1:].title()}",
		tile = {{ {x}, {y} }},
		ghost = true,{sprite}
		on_step = proc(_, by: Entity_Id) {{ if by == player() {{ {proc} }} }},
	}})""")

	out_f.write("}\n")

	out_f.write(f"\n{lr_lower}_player_spawn :: proc() -> (Tile, Direction, bool) {{\n")
	out_f.write("\tlv := &world.levels\n")
	out_f.write("\t_ = lv\n") # some levels, like those used just in cutscenes, don't reference other levels
	out_f.write("\tif tile, face, ok := try_spawn_from_save(); ok { return tile, face, true }\n")
	# ENTRANCES
	for n, (lfrom, pos, eFace, iFace, iOffset, i) in enumerate(entrances):
		x, y = pos
		stmt = f"if lv.prev == {lfrom.title()}"
		if i >= 0:
			stmt += f" && lv.egress_idx == {i}"
		if eFace:
			stmt += f" && lv.prev_face == .{eFace.title()}"
		iFace = iFace or (eFace or "Down")
		if iOffset:
			if iFace == "Down":
				y += 1
			elif iFace == "Up":
				y -= 1
			elif iFace == "Left":
				x -= 1
			elif iFace == "Right":
				x += 1
		out_f.write(f"{stmt} {{ return {{ {x}, {y} }}, .{iFace.title()}, true }}\n")
	out_f.write("return {}, .Down, false\n")
	out_f.write("}")

	out_f.close()

def write_case_proc(f, proc_name):
		f.write(
			f"""
	{proc_name}_level :: proc(l: Level) {{
	#partial switch l {{
	""")
		for lenum in level_enums:
			lname = lenum.lower()
			f.write(f"case .{lenum}:\n\t{proc_name}_{lname}()\n")
		f.write("}\n}\n\n")

# Tileset_Id and tileset_files for the map code, from the Tiled tilesets: the
# enum member is the tileset's name, title-cased; the file is its image's stem.
def write_tileset_data():
	tilesets = []
	for tsx in sorted(pathlib.Path(f"{ROOT}/tilesets").glob("*.tsx")):
		root = ET.parse(tsx).getroot()
		tilesets.append((root.get("name").title(), pathlib.Path(root.find("image").get("source")).stem))
	with open(f"{DEST}/tileset_data.odin", "w") as f:
		f.write("package game\n\nTileset_Id :: enum {\n")
		for name, _ in tilesets:
			f.write(f"\t{name},\n")
		f.write("}\n\n@(rodata)\ntileset_files := [Tileset_Id]string {\n")
		for name, stem in tilesets:
			f.write(f"\t.{name} = \"{stem}\",\n")
		f.write("}\n")

def export_tilesets():
	for file in pathlib.Path(TILESETS).glob("*.ase"):
		print(f"exporting {file}")
		subprocess.check_call(["aseprite", "-b", str(file), "--save-as", str(file.with_suffix(".png"))])

# Generated files are gitignored, so outputs of renamed or removed maps would
# linger, as would outputs from the old package layout (src/engine and
# src/content, now src/game; and level code that src/game held before it
# became src/rules).
def remove_stale_outputs():
	for pattern in ("level_*_data.odin", "level_data.odin", "encounter_region_data.odin"):
		for d in (DEST, RULES_DEST):
			for f in pathlib.Path(d).glob(pattern):
				f.unlink()
	for d in ("./src/engine", "./src/content"):
		for f in pathlib.Path(d).glob("*_data.odin"):
			f.unlink()
		if pathlib.Path(d).is_dir() and not any(pathlib.Path(d).iterdir()):
			pathlib.Path(d).rmdir()

def main():
	remove_stale_outputs()
	export_tilesets()
	write_tileset_data()
	for file in pathlib.Path(ROOT).rglob("*.tmx"):
		level_name = str(file.parent).split("/")[-1]
		room_name = str(file.name)[:-4]
		print(f"processing {level_name}/{room_name}.tmx")
		process_tmx(level_name, room_name)

	# The Level enum is saved game data (save points name levels), so it goes in
	# rules; the dispatch below runs level code, so it stays in game.
	with open(f"{RULES_DEST}/levels_data.odin", "w") as f:
		f.write("package rules\n\nLevel :: enum {\n")
		for lenum in level_enums + sorted(referenced_levels - set(level_enums)):
			f.write(f"\t{lenum},\n")
		f.write("}\n")

	with open(f"{DEST}/level_data.odin", "w") as levels_data_f:
		levels_data_f.write("package game\n")

		write_case_proc(levels_data_f, "tiled_init")
		write_case_proc(levels_data_f, "init")
		write_case_proc(levels_data_f, "render")

		levels_data_f.write("player_spawn_level :: proc(l: Level) -> (Tile, Direction, bool) {\n")
		levels_data_f.write("\t#partial switch l {\n")
		for lenum in level_enums:
			levels_data_f.write(f"\tcase .{lenum}: return {lenum.lower()}_player_spawn()\n")
		levels_data_f.write("\t}\n\treturn {}, .Down, false\n}\n\n")


	with open(f"{DEST}/encounter_region_data.odin", "w") as regions_f:
		regions_f.write("package game\n\nimport rl \"vendor:raylib\"\n_ :: rl // unused when no level has encounter regions\n\nEncounter_Region :: enum {\nNone,\n")
		for r in set(_s for _s in encounter_sets):
			regions_f.write(f"\t{r.title()},\n")
		regions_f.write("}\n\n")

		for _level, regions in encounter_regions.items():
			for (_poly, _), _r in regions:
				regions_f.write(f"@(rodata)\n{_level.upper()}_{_r.upper()} := {_poly}\n")

		regions_f.write("get_encounter_region :: proc(level: Level, tile: Tile) -> (r: Encounter_Region) {\n")
		regions_f.write("#partial switch level {\n")
		for _level, _regions in encounter_regions.items():
			regions_f.write("case .{}:\n".format(_level))
			regions_f.write("if false {\n")
			for (_poly, _len), _r in _regions:
				regions_f.write(f"}} else if rl.CheckCollisionPointPoly({{f32(tile.x), f32(tile.y)}}, &{_level.upper()}_{_r.upper()}[0], {_len}) {{\n")
				regions_f.write(f"r = .{_r}\n")
			regions_f.write("}\n")
		regions_f.write("}\nreturn\n")
		regions_f.write("}\n\n")

	with open(f"{RULES_DEST}/chest_data.odin", "w") as f:
		f.write("package rules\n\n")
		f.write("Chest_Datum :: enum {\n")
		for d in chest_data:
			f.write(f"\t{d},\n")
		f.write("}")

if __name__ == "__main__":
	main()
