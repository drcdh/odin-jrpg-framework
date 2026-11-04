package game

import hm "core:container/handle_map"

Trigger :: struct {
	running:  Script_Id,
	script:   Script_Proc, // nil = no trigger
}

new_trigger :: proc(script: Script_Proc) -> Trigger {
	return {script = script}
}

// `actor` talks (or "talks") to Entity in front
// will not run more than once simultaneously
interact :: proc(actor: Entity_Id) -> bool {
	a, ok := entity_get(actor)
	if !ok do return false
	target := a.tile + dir_vec(a.facing)

	it := hm.iterator_make(&game.entities)
	for e, h in hm.iterate(&it) {
		tr := &e.trigger
		if h == actor || e.tile != target || tr.script == nil do continue

		if script_alive(tr.running) do return false // script is already running
		tr.running = spawn(tr.script, h, e.name)
		return true
	}
	return false
}
