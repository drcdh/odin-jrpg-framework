package rules

import "core:log"

// A temporary stub until battles are ported: just the battle state that skill
// effects change. `c` comes first, so a ^Combatant passes as a ^Character.

Ticks :: f32

Combatant :: struct {
	using c: Character,
	ticks:   Ticks,
	windup:  bool, // winding up a skill; a stagger can interrupt it
}

// Breaks `target`'s windup. Returns false if they weren't winding up.
interrupt_windup :: proc(target: ^Combatant) -> bool {
	if !target.windup {
		log.infof("Tried to interrupt %s but they weren't winding up", target.name)
		return false
	}
	target.windup = false
	log.infof("Break! %s is interrupted", target.name)
	return true
}

roll_for_counter :: proc(actor, target: ^Combatant, risk: f32 = 1) {
}
