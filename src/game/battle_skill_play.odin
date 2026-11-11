package game

import "core:log"

// This procedure blocks
process_skill_play_2 :: proc(_: Entity_Id) {
	sp := battle.skill_play

	log.infof("Processing skill play: %v", sp)
	defer log.info("Processing skill play END")
	pause_battle(); defer pause_battle(false)

	actor := battle.combatants[sp.actor_idx]
	skill := skills[sp.skill_name]
	skill.procedure(actor, sp.targets) // blocks

	reset_character_charge(actor, Ticks(skill.cost))
	actor.windup = false

	update_character_sprite(battle.combatants[sp.actor_idx]^)
	battle_menu_set_stale(.Party)
}

// TODO: analogue for world menu skill plays
