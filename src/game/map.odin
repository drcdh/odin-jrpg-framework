package game

import hm "core:container/handle_map"
import "core:fmt"
import "core:log"
import "core:slice"
import rl "vendor:raylib"

TILESET_DIR :: "assets/tilesets"

// `Tileset_Id` and `tileset_files` (the PNG for each, exported from the .ase
// files) are generated into tileset_data.odin by process_tiled.py.

// Bits of a tile's passability flags (the generated PASSABLE tables).
PARTY_IMPASSABLE :: 1
BOAT_IMPASSABLE  :: 2 // unused until there are boats

Map_Mode :: enum {
	DEFAULT, // outside the map is empty
	CLAMP,   // the camera stays inside the map
	WRAP,    // the map repeats in every direction
}

// The current level's map, filled in by the generated tiled_init_* procs
// (set_map) and render_* procs (begin_map_render .. end_map_render).
Level_Map :: struct {
	battle_background: Battle_Background,
	firstgids: []int,
	mode:      Map_Mode,
	open_edges: bool,            // outside the map is passable (the level has an edge exit)
	passable:  []u8,             // flags per in-map tile, row-major; empty means all passable
	routes:    [][]Tile,
	rt:        rl.RenderTexture, // the whole map, rendered once on entry
	size:      Tile,             // in tiles
	tilesets:  []Tileset_Id,     // Tiled order, parallel to firstgids
}

// Takes the generated map data.
set_map :: proc(m: Level_Map) {
	assert(len(m.passable) == 0 || len(m.passable) == int(m.size.x * m.size.y), "passable must have a flag per tile")
	unload_map()
	world.level_map = m
}

set_map_mode :: proc(mode: Map_Mode) {
	world.level_map.mode = mode
}

map_pixel_size :: proc() -> [2]f32 {
	return {f32(world.level_map.size.x), f32(world.level_map.size.y)} * TILE_SIZE
}

map_contains :: proc(t: Tile) -> bool {
	s := world.level_map.size
	return t.x >= 0 && t.y >= 0 && t.x < s.x && t.y < s.y
}

// Whether `mover` can step onto `t`: the map lets the party through and no
// other entity is in the way. In WRAP mode tiles wrap around the map;
// otherwise outside the map is passable only with `open_edges`.
tile_free :: proc(t: Tile, mover: Entity_Id = {}) -> bool {
	return tile_passable(t) && !tile_occupied(t, mover)
}

tile_passable :: proc(t: Tile) -> bool {
	m := &world.level_map
	if m.size == {} do return true // no map loaded
	w := wrap_tile(t)
	if !map_contains(w) do return m.open_edges
	if len(m.passable) == 0 do return true
	return m.passable[w.y * m.size.x + w.x] & PARTY_IMPASSABLE == 0
}

// Whether a solid entity other than `mover` is on `t`. A ghost mover is never
// blocked, and ghosts never block. An entity's tile changes when its move
// starts, so a tile being walked onto is already taken.
tile_occupied :: proc(t: Tile, mover: Entity_Id = {}) -> bool {
	if m, ok := entity_get(mover); ok && m.ghost do return false
	w := wrap_tile(t)
	it := hm.iterator_make(&game.entities)
	for e, h in hm.iterate(&it) {
		if h != mover && !e.ghost && wrap_tile(e.tile) == w do return true
	}
	return false
}

// A shortest walk from `from` to `to` over passable tiles (tile_passable), as
// unit steps, ignoring entities. Without WRAP it stays inside the map; in
// WRAP mode it can cross the seam. With no map loaded it's the direct
// x-then-y walk. `ok` is false if `to` can't be reached. Searching Up, Down,
// Left, Right in that order makes the path deterministic.
find_path :: proc(from, to: Tile, allocator := context.allocator) -> (steps: []Tile, ok: bool) {
	m := &world.level_map
	if m.size == {} {
		d := to - from
		out := make([dynamic]Tile, 0, abs(d.x) + abs(d.y), allocator)
		for _ in 0..<abs(d.x) do append(&out, Tile{1 if d.x > 0 else -1, 0})
		for _ in 0..<abs(d.y) do append(&out, Tile{0, 1 if d.y > 0 else -1})
		return out[:], true
	}
	start, goal := wrap_tile(from), wrap_tile(to)
	if !map_contains(start) || !map_contains(goal) do return nil, false
	if start == goal do return nil, true

	dirs := [4]Tile{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	index :: proc(t: Tile) -> int { return int(t.y * world.level_map.size.x + t.x) }
	// came[i] is 1 + the dirs index of the step into tile i; 0 = not reached.
	came := make([]u8, int(m.size.x * m.size.y), context.temp_allocator)
	queue := make([dynamic]Tile, 0, len(came), context.temp_allocator)
	came[index(start)] = 255 // reached, as the start
	append(&queue, start)
	search: for head := 0; head < len(queue); head += 1 {
		for d, k in dirs {
			next := queue[head] + d
			if m.mode == .WRAP do next = wrap_tile(next)
			else if !map_contains(next) do continue
			if came[index(next)] != 0 || !tile_passable(next) do continue
			came[index(next)] = u8(k + 1)
			if next == goal do break search
			append(&queue, next)
		}
	}
	if came[index(goal)] == 0 do return nil, false

	out := make([dynamic]Tile, allocator)
	for t := goal; t != start; {
		d := dirs[came[index(t)] - 1]
		append(&out, d)
		t = wrap_tile(t - d)
	}
	slice.reverse(out[:])
	return out[:], true
}

// `t` wrapped into the map in WRAP mode; unchanged otherwise.
wrap_tile :: proc(t: Tile) -> Tile {
	m := &world.level_map
	if m.mode != .WRAP || m.size.x <= 0 || m.size.y <= 0 do return t
	return {t.x %% m.size.x, t.y %% m.size.y}
}

// A route from the map's Tiled polylines and polygons, by index (the
// generated <LEVEL>_<NAME> constants).
map_route :: proc(i: int) -> []Tile {
	return world.level_map.routes[i]
}

// --- Rendering, main thread only. Without a window these do nothing. ---

begin_map_render :: proc() {
	assert(!in_script(), "maps must be rendered on the main thread")
	if !rl.IsWindowReady() do return
	unload_map()
	size := world.level_map.size * TILE_SIZE
	world.level_map.rt = rl.LoadRenderTexture(size.x, size.y)
	rl.BeginTextureMode(world.level_map.rt)
	rl.ClearBackground(rl.BLANK)
}

// `gid` is a Tiled global tile id; 0 is an empty cell.
draw_map_tile :: proc(gid: int, i, j: int) {
	if !rl.IsWindowReady() do return
	ts, t := map_gid_tile(world.level_map, gid)
	if t < 0 do return
	tex := tileset_texture(ts)
	cols := int(tex.width) / TILE_SIZE
	if cols == 0 do return
	src := rl.Rectangle{f32(t % cols) * TILE_SIZE, f32(t / cols) * TILE_SIZE, TILE_SIZE, TILE_SIZE}
	rl.DrawTextureRec(tex, src, {f32(i), f32(j)} * TILE_SIZE, rl.WHITE)
}

end_map_render :: proc() {
	if !rl.IsWindowReady() do return
	rl.EndTextureMode()
	// For WRAP; clipped draws in the other modes never sample past the edge.
	rl.SetTextureWrap(world.level_map.rt.texture, .REPEAT)
}

unload_map :: proc() {
	if world.level_map.rt.id != 0 do rl.UnloadRenderTexture(world.level_map.rt)
	world.level_map.rt = {}
}

// World space, inside BeginMode2D: the part of the map the camera sees.
draw_map :: proc() {
	m := &world.level_map
	if m.rt.id == 0 do return
	src := visible_world_rect()
	if m.mode != .WRAP {
		size := map_pixel_size()
		x0, y0 := max(src.x, 0), max(src.y, 0)
		x1, y1 := min(src.x + src.width, size.x), min(src.y + src.height, size.y)
		if x1 <= x0 || y1 <= y0 do return
		src = {x0, y0, x1 - x0, y1 - y0}
	}
	// Render textures are stored bottom-up: world row y is texture row H - y,
	// and a negative source height flips the rows back.
	flipped := rl.Rectangle{src.x, map_pixel_size().y - src.y - src.height, src.width, -src.height}
	rl.DrawTexturePro(m.rt.texture, flipped, src, {}, 0, rl.WHITE)
}

// The world rect the screen covers under the current camera.
visible_world_rect :: proc() -> rl.Rectangle {
	tl := rl.GetScreenToWorld2D({0, 0}, world.camera)
	br := rl.GetScreenToWorld2D({f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}, world.camera)
	return {tl.x, tl.y, br.x - tl.x, br.y - tl.y}
}

// Which tileset a gid belongs to, and its index there; -1 for an empty cell.
map_gid_tile :: proc(m: Level_Map, gid: int) -> (Tileset_Id, int) {
	if gid <= 0 || len(m.firstgids) == 0 do return {}, -1
	ts := len(m.firstgids) - 1
	for ts > 0 && gid < m.firstgids[ts] do ts -= 1
	if gid < m.firstgids[ts] do return {}, -1
	return m.tilesets[ts], gid - m.firstgids[ts]
}

@(private)
tileset_texture :: proc(ts: Tileset_Id) -> rl.Texture {
	if game.tilesets[ts].id == 0 {
		path := fmt.ctprintf("%s/%s.png", TILESET_DIR, tileset_files[ts])
		game.tilesets[ts] = rl.LoadTexture(path)
		if game.tilesets[ts].id == 0 do log.errorf("could not load %s (run process_tiled.py?)", path)
	}
	return game.tilesets[ts]
}
