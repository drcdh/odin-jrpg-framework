package game

import "core:log"
import "core:time"
import "../engine"

// Names the generated level code (process_tiled.py) uses.
Tile_T     :: i32
Tile_Coord :: engine.Tile
Tileset_Id :: engine.Tileset_Id
Sprite_Tag :: engine.Sprite_Tag

current_level:         Level
prev_level:            Level
prev_level_tile:       Tile_Coord
prev_level_face:       Sprite_Tag
prev_level_egress_idx: int

// Leaves the current level and enters `l`: the generated tiled_init_* sets the
// map, the hand-written init_* spawns the level's entities, and the generated
// render_* draws the map once.
start_level :: proc(l: Level) {
	start := time.tick_now()
	if p, ok := engine.entity_get(engine.player()); ok {
		prev_level_face = engine.direction_tag(p.facing)
		prev_level_tile = p.tile
	}
	prev_level = current_level
	current_level = l
	engine.clear_level()

	tiled_init_level(l)
	init_level(l)
	render_level(l)

	engine.camera_follow(engine.player())
	log.infof("loaded level %v (%v tiles) in %v", l, engine.world.level_map.size, time.tick_since(start))
}

restart_level :: proc() {
	start_level(current_level)
}
