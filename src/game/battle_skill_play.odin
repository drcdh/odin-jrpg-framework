package game

import "core:log"

// This procedure blocks
process_skill_play :: proc(_: Entity_Id) {
	sp := battle.skill_play

	log.infof("Processing skill play: %v", sp)
	defer log.info("Processing skill play END")
	pause_battle(); defer pause_battle(false)

	actor := battle.combatants[sp.actor_idx]
	skill := skills[sp.skill_name]
	targets: [dynamic]^Character; defer delete(targets)
	target_selection_characters(sp.targets, &targets)
	skill.procedure(actor, targets[:]) // blocks

	reset_character_charge(actor, Ticks(skill.cost))
	actor.windup = false

	update_character_sprite(actor^)
	for target in targets { update_character_sprite(target^) }

	battle_menu_set_stale(.Party)
}
