package engine

import hm "core:container/handle_map"
import "core:math/linalg"

Trigger_Mode :: enum u8 {
	On_Enter, // every time the player enters the radius
	Once,     // only the first time
	Cooldown, // on enter, at most once per `cooldown` seconds
}

// Runs `script` on the owning entity when the player walks into `radius`.
// A trigger never runs its script twice at once.
Trigger :: struct {
	script:     Script_Proc, // nil = no trigger
	radius:     f32,
	mode:       Trigger_Mode,
	cooldown:   f32,

	was_inside: bool,
	fired:      bool,
	ready_at:   f64,
	running:    Script_Id,
}

triggers_update :: proc() {
	player, ok := entity_get(world.player)
	if !ok do return
	ppos := player.pos

	it := hm.iterator_make(&world.entities)
	for e, h in hm.iterate(&it) {
		tr := &e.trigger
		if tr.script == nil || h == world.player do continue

		inside := linalg.distance(ppos, e.pos) <= tr.radius
		entered := inside && !tr.was_inside
		tr.was_inside = inside
		if !entered || script_alive(tr.running) do continue

		switch tr.mode {
		case .On_Enter:
		case .Once:
			if tr.fired do continue
		case .Cooldown:
			if world.clock.time < tr.ready_at do continue
		}
		tr.fired = true
		tr.ready_at = world.clock.time + f64(tr.cooldown)
		tr.running = spawn(tr.script, h, e.name)
	}
}
