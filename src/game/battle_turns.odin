package game

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:time"

take_turn :: proc(actor_idx: int) {
	start := time.tick_now()

	c := battle.combatants[actor_idx]
	available_skills: [dynamic]int; defer delete(available_skills)
	for cs, cs_idx in c.skills {
		if cs.charge == CHARGE_MAX {
			append(&available_skills, cs_idx)
		}
	}
	if len(available_skills) > 0 {
		cs_idx := rand.choice(available_skills[:])
		k := c.skills[cs_idx].skill
		fmt.printfln("%s picked skill %s", c.name, k)

		team := c.team
		if has_any_status(c^, .Control) do team = opposite_team(team)
		if has_any_status(c^, .Confuse, .Rage, .Zombie) do team = .None

		if target, valid := random_target(k, team); valid {
			c.skills[cs_idx].charge = 0
			queue_battle_skill(actor_idx, target, k)
		} else {
			fmt.printfln("no valid target for %v", k)
		}
	} else {
		fmt.printfln("%s twiddles their thumbs", c.name)
	}

	log.infof("combatant %d %s took turn in %v", actor_idx, c.name, time.tick_since(start))
}
