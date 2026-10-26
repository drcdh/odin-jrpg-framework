package rules

import "core:math/rand"

BADDY_TEAM :: 0
PLAYER_TEAM :: 1

Target_Selection :: union {
	Target_One_Ally,
	Target_One_Baddy,
	Target_All_Allies,
	Target_All_Baddies,
	Target_All_Combatants,
}
Target_One_Ally :: struct {
	i: int,
}
Target_One_Baddy :: struct {
	i: int,
}
Target_All_Baddies :: struct {
	prev: int,
}
Target_All_Allies :: struct {
	prev: int,
}
Target_One_Combatant :: struct {
	i: int,
}
Target_All_Combatants :: struct {}

Target_Type :: enum {
	One_Opponent,
	Some_Opponents,
	All_Opponents,
	One_Ally,
	Some_Allies,
	All_Allies,
	One_Combatant,
	All_Combatants,
}

random_ally_target :: proc() -> (target: Maybe(Target_One_Ally)) {
	targets: [dynamic]int
	defer delete(targets)
	for c_idx, ally_idx in battle.allies {
		if combatant_alive(battle.combatants[c_idx]) {
			append(&targets, ally_idx)
		}
	}
	if len(targets) > 0 {
		target = Target_One_Ally{rand.choice(targets[:])}
	}
	return
}

random_baddy_target :: proc(target_all_prob := 0) -> (target: Maybe(Target_One_Baddy)) {
	targets: [dynamic]int
	defer delete(targets)
	for c_idx, baddy_idx in battle.baddies {
		if combatant_alive(battle.combatants[c_idx]) {
			append(&targets, baddy_idx)
		}
	}
	if len(targets) > 0 {
		target = Target_One_Baddy{rand.choice(targets[:])}
	}
	return
}

// TODO status/living/dead restrictions
random_target :: proc(
	targeting: Target_Type,
	opponent_team: Maybe(int),
	target_all_prob := .5,
) -> (
	target: Target_Selection,
	valid: bool,
) {
	if opponent_team == nil {panic("Oops! Need to implement this")}

	switch targeting {
	case .One_Opponent:
		switch opponent_team {
		case PLAYER_TEAM:
			target, valid = random_ally_target().?
		case BADDY_TEAM:
			target, valid = random_baddy_target().?
		}
	case .Some_Opponents:
		if opponent_team == PLAYER_TEAM {
			if false {
				target, valid = Target_All_Allies{}, true
			} else {
				target, valid = random_ally_target().?
			}
		} else if opponent_team == BADDY_TEAM {
			if false {
				target, valid = Target_All_Baddies{}, true
			} else {
				target, valid = random_baddy_target().?
			}
		}
	case .All_Opponents:
		target = Target_All_Allies{} if opponent_team == PLAYER_TEAM else Target_All_Baddies{}
		valid = true
	case .One_Ally:
		if opponent_team == PLAYER_TEAM {
			target, valid = random_ally_target().?
		} else if opponent_team == BADDY_TEAM {
			target, valid = random_baddy_target().?
		}
	case .Some_Allies:
		if opponent_team == BADDY_TEAM {
			if false {
				target, valid = Target_All_Allies{}, true
			} else {
				target, valid = random_ally_target().?
			}
		} else if opponent_team == PLAYER_TEAM {
			if false {
				target, valid = Target_All_Baddies{}, true
			} else {
				target, valid = random_baddy_target().?
			}
		}
	case .All_Allies:
		target = Target_All_Allies{} if opponent_team == BADDY_TEAM else Target_All_Baddies{}
		valid = true
	case .One_Combatant:
		valid = false // TODO
	case .All_Combatants:
		target, valid = Target_All_Combatants{}, true
	}
	return
}
