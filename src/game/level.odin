package game

import "core:log"
import "core:time"
import "../engine"

// Names the generated level code (process_tiled.py) uses.
Tile_T     :: i32
Tile_Coord :: engine.Tile
Tileset_Id :: engine.Tileset_Id
Sprite_Tag :: engine.Sprite_Tag

FADE_TIME :: 0.25 // seconds for each half of a level change

current_level:         Level
prev_level:            Level
prev_level_tile:       Tile_Coord
prev_level_face:       Sprite_Tag
prev_level_egress_idx: int

// Where stepping off the map edge goes (egress index 0); nil when the edges
// are closed. Set by the generated tiled_init_* from the map's edge_level property.
edge_level: Maybe(Level)

// The level being faded to, and the curtain tween of the current fade.
pending_level: Maybe(Level)
transition:    engine.Tween_Id

// Leaves the current level and enters `l`. The generated tiled_init_* sets
// the map and its doors, the player spawns (at `at`, or by the level's
// entrance rules), the hand-written init_* adds the rest, and the generated
// render_* draws the map once.
start_level :: proc(l: Level, at: Maybe(Tile_Coord) = nil) {
	start := time.tick_now()
	if p, ok := engine.entity_get(engine.player()); ok {
		prev_level_face = engine.direction_tag(p.facing)
		prev_level_tile = p.tile
	}
	prev_level = current_level
	current_level = l
	engine.clear_level()
	edge_level = nil

	tiled_init_level(l)
	engine.set_map_passability(proc(t: Tile_Coord) -> u8 { return passable(current_level, t.x, t.y) })
	spawn_player(l, at)
	init_level(l)
	render_level(l)

	engine.camera_follow(engine.player())
	log.infof("loaded level %v (%v tiles) in %v", l, engine.world.level_map.size, time.tick_since(start))
}

restart_level :: proc() {
	start_level(current_level)
}

// Leaving through a door or the map edge: fade out, enter `l`, fade in. The
// destination's entrance rules pick the spawn from the level left, the door
// index and the player's facing. Ignored while a level change is under way.
egress :: proc(l: Level, egress_idx: int) {
	if _, busy := pending_level.?; busy do return
	prev_level_egress_idx = egress_idx
	pending_level = l
	transition = engine.curtain_to(1, FADE_TIME)
}

// A warp pad. Same as egress until there are sounds to tell them apart.
warp_to_level :: proc(l: Level, egress_idx: int) {
	egress(l, egress_idx)
}

// Runs a level change. True while one is under way (including the fade back
// in), so the game ignores input.
update_transition :: proc() -> bool {
	if l, ok := pending_level.?; ok {
		if !engine.tween_done(transition) do return true
		pending_level = nil
		start_level(l)
		transition = engine.curtain_to(0, FADE_TIME)
		return true
	}
	return !engine.tween_done(transition)
}

// Called when the player finishes a step: stepping off the map edge leaves
// the level, if it has an edge exit.
check_edge_exit :: proc() {
	l, ok := edge_level.?
	if !ok || engine.map_contains(engine.entity_tile(engine.player())) do return
	egress(l, 0)
}

@(private = "file")
spawn_player :: proc(l: Level, at: Maybe(Tile_Coord)) {
	tile, face := Tile_Coord{}, Sprite_Tag.Down
	if t, ok := at.?; ok {
		tile = t
	} else if t2, f, found := player_spawn_level(l); found {
		tile, face = t2, f
	} else {
		tile = engine.world.level_map.size / 2
		log.errorf("%v has no entrance for %v door %d facing %v; spawning the player at the map center %v",
			l, prev_level, prev_level_egress_idx, prev_level_face, tile)
	}
	player := engine.spawn_entity({
		name   = "player",
		tile   = tile,
		facing = engine.tag_direction(face),
		sprite = character_sprite(PLAYER_BODY, layer = 1),
	})
	engine.set_player(player)
}
