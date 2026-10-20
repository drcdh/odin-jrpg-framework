package engine

import hm "core:container/handle_map"

Trigger_Mode :: enum u8 {
	Repeat,   // every time it's talked to
	Once,     // only the first time
	Cooldown, // at most once per `cooldown` seconds
}

// Runs `script` on the owning entity when another entity talks to it (see interact).
// A trigger never runs its script twice at once.
Trigger :: struct {
	script:   Script_Proc, // nil = no trigger
	mode:     Trigger_Mode,
	cooldown: f32,

	fired:    bool,
	ready_at: f64,
	running:  Script_Id,
}

// `actor` talks to whatever is on the tile it faces. The first entity there
// with a trigger turns to face the actor and starts its script. Returns
// whether a script started.
interact :: proc(actor: Entity_Id) -> bool {
	a, ok := entity_get(actor)
	if !ok do return false
	target := a.tile + dir_vec(a.facing)
	facing := dir_opposite(a.facing)

	it := hm.iterator_make(&world.entities)
	for e, h in hm.iterate(&it) {
		tr := &e.trigger
		if h == actor || e.tile != target || tr.script == nil do continue

		if script_alive(tr.running) do return false
		switch tr.mode {
		case .Repeat:
		case .Once:
			if tr.fired do return false
		case .Cooldown:
			if world.clock.time < tr.ready_at do return false
		}
		tr.fired = true
		tr.ready_at = world.clock.time + f64(tr.cooldown)
		e.facing = facing
		tr.running = spawn(tr.script, h, e.name)
		return true
	}
	return false
}
