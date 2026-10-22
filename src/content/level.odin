package content

import "core:log"
import "core:time"
import "../engine"

// Names the generated level code (process_tiled.py) uses.
Tile_T     :: i32
Tileset_Id :: engine.Tileset_Id

// The engine's Level_Enter hook (engine.start_level): the generated
// tiled_init_* sets the map and its doors, the player spawns (at `at`, or by
// the level's entrance rules), the hand-written init_* adds the rest, and the
// generated render_* draws the map once.
enter_level :: proc(l: Level, at: Maybe(engine.Tile), face: engine.Direction) {
	start := time.tick_now()
	tiled_init_level(l)
	engine.set_map_passability(proc(t: engine.Tile) -> u8 { return passable(engine.current_level(), t.x, t.y) })
	spawn_player(l, at, face)
	init_level(l)
	render_level(l)
	log.infof("loaded level %v (%v tiles) in %v", l, engine.world.level_map.size, time.tick_since(start))
}

@(private = "file")
spawn_player :: proc(l: Level, at: Maybe(engine.Tile), at_face: engine.Direction) {
	tile, face := engine.Tile{}, engine.Direction.Down
	if t, ok := at.?; ok {
		tile, face = t, at_face
	} else if t2, f, found := player_spawn_level(l); found {
		tile, face = t2, f
	} else {
		lv := &engine.world.levels
		tile = engine.world.level_map.size / 2
		log.errorf("%v has no entrance for %v door %d facing %v; spawning the player at the map center %v",
			l, lv.prev, lv.egress_idx, lv.prev_face, tile)
	}
	player := engine.spawn_entity({
		name   = "player",
		tile   = tile,
		facing = face,
		sprite = character_sprite(PLAYER_BODY, layer = 1),
	})
	engine.set_player(player)
}
