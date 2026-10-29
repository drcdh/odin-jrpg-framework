package game

import hm "core:container/handle_map"

// Runs `script` on the owning entity when another entity talks to it (see interact).
// A trigger never runs its script twice at once. The entity's busy flag is
// cleared when the script finishes.
Trigger :: struct {
	autobusy:				 bool,        // busy (set_busy) for the script, so other scripts can't move or turn it
	autobusy_actor:  bool,        // set actor (usually the player) busy for the script
	autoface:				 bool,        // turn to face whoever talks
	running:  			 Script_Id,
	script:   			 Script_Proc, // nil = no trigger
}

// A trigger that, by default, faces the talker and is busy while it runs.
new_trigger :: proc(script: Script_Proc, autoface := true, autobusy := true, autobusy_actor := true) -> Trigger {
	return {script = script, autoface = autoface, autobusy = autobusy, autobusy_actor = autobusy_actor}
}

// `actor` talks to whatever is on the tile it faces. The first entity there
// with a trigger starts its script, after turning to face the actor
// (autoface) and becoming busy for the script (autobusy). Returns whether a
// script started.
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
		if tr.autoface do e.facing = dir_opposite(a.facing)
		if tr.autobusy {
			e.busy = true
			e.busy_by = tr.running
		}
		if tr.autobusy_actor {
			a.busy = true
			a.busy_by = tr.running
		}
		return true
	}
	return false
}
