package engine

import hm "core:container/handle_map"

// The level-independent part of leaving a level. Everything a level added to
// the world goes: every entity, every tween, every script (cancelled ones
// finish on the next update), and the map. The game's start_level then sets
// up the next one.
clear_level :: proc() {
	it := hm.iterator_make(&world.entities)
	for _, h in hm.iterate(&it) do destroy_entity(h)
	entities_flush_destroyed()
	for h in world.script_order do script_cancel(h)
	// Remove rather than clear, so stale Tween_Ids stay invalid.
	tw := hm.iterator_make(&world.tweens)
	for _, h in hm.iterate(&tw) do hm.remove(&world.tweens, h)
	unload_map()
	world.level_map = {}
	world.player = {}
	world.camera_follow = {}
}
