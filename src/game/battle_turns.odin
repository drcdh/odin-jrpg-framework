package game

import "core:fmt"
import "core:math/rand"

default_turn :: proc(actor_idx: int, opponent_team: Maybe(int)) {
	c := &battle.combatants[actor_idx]
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
		if target, valid := random_target(skills[k].targeting, opponent_team); valid {
			c.skills[cs_idx].charge = 0
			queue_battle_skill(actor_idx, target, k)
		} else {
			fmt.printfln("no valid target for %v", k)
		}
	} else {
		fmt.printfln("%s twiddles their thumbs", c.name)
	}
}
