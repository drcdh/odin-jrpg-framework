package engine

import hm "core:container/handle_map"

// Runs `script` on the owning entity when another entity talks to it (see interact).
// A trigger never runs its script twice at once.
Trigger :: struct {
	script:   Script_Proc, // nil = no trigger
	running:  Script_Id,
}

// `actor` talks to whatever is on the tile it faces. The first entity there
// with a trigger turns to face the actor and starts its script. Returns
// whether a script started.
interact :: proc(actor: Entity_Id) -> bool {
	a, ok := entity_get(actor)
	if !ok do return false
	target := a.tile + dir_vec(a.facing)

	it := hm.iterator_make(&world.entities)
	for e, h in hm.iterate(&it) {
		tr := &e.trigger
		if h == actor || e.tile != target || tr.script == nil do continue

		if script_alive(tr.running) do return false
		tr.running = spawn(tr.script, h, e.name)
		return true
	}
	return false
}
