package engine

import hm "core:container/handle_map"
import "core:log"

// idx 0 is the handle map's sentinel, so `Entity_Id{}` means "no entity".
Entity_Id :: distinct hm.Handle32

Entity :: struct {
	handle:  Entity_Id, // required by the handle map; set by spawn_entity
	name:    string,
	tile:    Tile,      // logical cell; changes as soon as a move starts
	pos:     [2]f32,    // visual position in world pixels; set from `tile` on spawn
	facing:  Direction,
	ghost:   bool,      // neither blocks nor is blocked by other entities
	sprite:  Sprite_State,
	trigger: Trigger,
}

// Handles are the only references to keep around. An ^Entity from entity_get
// must not be held across a script yield or a spawn/destroy.
spawn_entity :: proc(e: Entity) -> Entity_Id {
	e := e
	e.pos = tile_center(e.tile)
	h, err := hm.add(&world.entities, e)
	assert(err == nil, "out of memory spawning entity")
	return h
}

entity_get :: proc(id: Entity_Id) -> (^Entity, bool) #optional_ok {
	return hm.get(&world.entities, id)
}

entity_alive :: proc(id: Entity_Id) -> bool {
	return hm.is_valid(&world.entities, id)
}

// Linear scan, so resolve once at the top of a script and keep the handle.
// Returns `Entity_Id{}` and logs a warning if no entity has that name; with
// duplicate names, the first in handle-map order wins.
find :: proc(name: string, loc := #caller_location) -> Entity_Id {
	it := hm.iterator_make(&world.entities)
	for e, h in hm.iterate(&it) {
		if e.name == name do return h
	}
	log.warnf("find: no entity named %q", name, location = loc)
	return {}
}

entity_pos :: proc(id: Entity_Id) -> [2]f32 {
	if e, ok := entity_get(id); ok do return e.pos
	return {}
}

entity_tile :: proc(id: Entity_Id) -> Tile {
	if e, ok := entity_get(id); ok do return e.tile
	return {}
}

// Destruction is deferred to the end of update, so the entity stays valid for
// the rest of the frame. Its tweens and the scripts running on it are cancelled.
destroy_entity :: proc(id: Entity_Id) {
	if !entity_alive(id) do return
	for pending in world.pending_destroy do if pending == id do return
	append(&world.pending_destroy, id)
}

entities_flush_destroyed :: proc() {
	for id in world.pending_destroy {
		tweens_cancel_for_entity(id)
		scripts_cancel_for_entity(id)
		hm.remove(&world.entities, id)
	}
	clear(&world.pending_destroy)
}
