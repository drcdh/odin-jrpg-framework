package game

// import sa "core:container/small_array"
// import "core:fmt"
import "core:log"

// This procedure blocks
process_skill_play_2 :: proc(_: Entity_Id) {
	sp := battle.skill_play

	log.infof("Processing skill play: %v", sp)
	defer log.info("Processing skill play END")
	pause_battle(); defer pause_battle(false)

	actor := battle.combatants[sp.actor_idx]
	skill := skills[sp.skill_name]
	targets: [dynamic]^Character; defer clear(&targets)
	target_selection_characters(sp.targets, &targets)
	skill.procedure(actor, targets[:]) // blocks

	actor.windup = false

	update_character_sprite(actor^)
	for target in targets { update_character_sprite(target^) }

	battle_menu_set_stale(.Party)
}

// TODO: analogue for world menu skill plays

// TODO: move this somewhere better?
// downed_proc :: proc() -> Script_Id {
// 	return spawn(proc(_: Entity_Id) {
// 		scripts: sa.Small_Array(MAX_COMBATANTS, Script_Id)
// 		for c_idx in battle.players {
// 			c := battle.combatants[c_idx]
// 			if !downed(c^) do continue
// 			sa.push(&scripts, spawn(player_down, c.eid, name = fmt.tprintf("player %s down", c.name)))
// 		}
// 		for c_idx in battle.baddies {
// 			c := battle.combatants[c_idx]
// 			if !downed(c^) do continue
// 			sa.push(&scripts, spawn(baddy_down, c.eid, name = fmt.tprintf("baddy %s down", c.name)))
// 		}
// 		l := sa.len(scripts)
// 		if l > 0 {
// 			pause_battle()
// 			log.infof("running %d down procedures", l)
// 			for s in sa.slice(&scripts) {
// 				if !wait_script(s) do return
// 			}
// 			pause_battle(false)
// 		}
// 	})
// }
