package rules

import "core:fmt"
import "core:math/rand"

default_turn :: proc(actor_idx: int, opponent_team: Maybe(int)) {
	c := battle.combatants[actor_idx]
	available_skills: [dynamic]Skill_Name; defer delete(available_skills)
	for cs in c.skills {
		if cs.charge == CHARGE_MAX {
			append(&available_skills, cs.skill)
		}
	}
	if len(available_skills) > 0 {
		k := rand.choice(available_skills[:])
		fmt.printfln("%s picked skill %s", c.name, k)
		if target, valid := random_target(skills[k].targeting, opponent_team); valid {
			queue_battle_skill(actor_idx, target, k)
		} else {
			fmt.printfln("no valid target for %v", k)
		}
	} else {
		fmt.printfln("%s twiddles their thumbs", c.name)
	}
}
