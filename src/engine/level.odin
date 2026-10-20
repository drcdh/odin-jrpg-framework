package engine

import hm "core:container/handle_map"

// The level-independent part of leaving a level: every entity goes (and with
// them their tweens and scripts, which finish on the next update), along with
// the map. The game's start_level then sets up the next one.
clear_level :: proc() {
	it := hm.iterator_make(&world.entities)
	for _, h in hm.iterate(&it) do destroy_entity(h)
	entities_flush_destroyed()
	unload_map()
	world.level_map = {}
	world.player = {}
	world.camera_follow = {}
}
