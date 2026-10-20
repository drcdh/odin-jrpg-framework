package engine

import hm "core:container/handle_map"

// idx 0 is the handle map's sentinel, so `Entity_Id{}` means "no entity".
Entity_Id :: distinct hm.Handle32

Entity :: struct {
	handle:  Entity_Id, // required by the handle map; set by spawn_entity
	name:    string,
	pos:     [2]f32,
	sprite:  Sprite,
	trigger: Trigger,
}

// Handles are the only references to keep around. An ^Entity from entity_get
// must not be held across a script yield or a spawn/destroy.
spawn_entity :: proc(e: Entity) -> Entity_Id {
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

entity_pos :: proc(id: Entity_Id) -> [2]f32 {
	if e, ok := entity_get(id); ok do return e.pos
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
