package engine

import "core:fmt"
import "core:log"
import rl "vendor:raylib"

TILESET_DIR :: "assets/tilesets"

// Tiled tileset names, title-cased, as process_tiled.py writes them.
Tileset_Id :: enum {
	Tileset_Terrain,
}

// PNGs in TILESET_DIR, exported from the .ase files by process_tiled.py.
@(rodata)
tileset_files := [Tileset_Id]string {
	.Tileset_Terrain = "tileset_terrain",
}

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
	size:      Tile,             // in tiles
	mode:      Map_Mode,
	tilesets:  []Tileset_Id,     // Tiled order, parallel to firstgids
	firstgids: []int,
	routes:    [][]Tile,
	passability: proc(t: Tile) -> u8, // flags for an in-map tile; nil means all passable
	rt:        rl.RenderTexture, // the whole map, rendered once on entry
}

// Takes the generated map data; the current mode and passability are kept.
set_map :: proc(m: Level_Map) {
	mode, passability := world.level_map.mode, world.level_map.passability
	unload_map()
	world.level_map = m
	world.level_map.mode = mode
	if m.passability == nil do world.level_map.passability = passability
}

set_map_passability :: proc(p: proc(t: Tile) -> u8) {
	world.level_map.passability = p
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

// Whether the party can step onto `t`. In WRAP mode tiles wrap around the
// map; otherwise anything outside the map is free, as in the old project.
// Entities don't block yet.
tile_free :: proc(t: Tile) -> bool {
	m := &world.level_map
	t := t
	if m.mode == .WRAP && m.size.x > 0 && m.size.y > 0 {
		t.x %%= m.size.x
		t.y %%= m.size.y
	} else if !map_contains(t) {
		return true
	}
	if m.passability == nil do return true
	return m.passability(t) & PARTY_IMPASSABLE == 0
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
	if world.tilesets[ts].id == 0 {
		path := fmt.ctprintf("%s/%s.png", TILESET_DIR, tileset_files[ts])
		world.tilesets[ts] = rl.LoadTexture(path)
		if world.tilesets[ts].id == 0 do log.errorf("could not load %s (run process_tiled.py?)", path)
	}
	return world.tilesets[ts]
}
