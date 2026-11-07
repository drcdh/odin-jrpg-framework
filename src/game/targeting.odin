package game

import "core:math/rand"

BADDY_TEAM :: 0
PLAYER_TEAM :: 1

Target_Selection :: union {
	Target_One_Ally,
	Target_One_Baddy,
	// Target_One_Combatant,
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

random_baddy_target :: proc() -> (target: Maybe(Target_One_Baddy)) {
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

random_combatant_target :: proc() -> (target: Maybe(Target_Selection)) {
	targets: [dynamic]int
	defer delete(targets)
	for c, c_idx in battle.combatants {
		if combatant_alive(c) {
			append(&targets, c_idx)
		}
	}
	if len(targets) > 0 {
		target_c_idx := rand.choice(targets[:])
		if battle.combatants[target_c_idx].team == PLAYER_TEAM {
			for c_idx, ally_idx in battle.allies {
				if c_idx == target_c_idx do return Target_One_Ally{ally_idx}
			}
		} else if battle.combatants[target_c_idx].team == BADDY_TEAM {
			for c_idx, baddy_idx in battle.baddies {
				if c_idx == target_c_idx do return Target_One_Baddy{baddy_idx}
			}
		}
	}
	return
}

coinflip :: proc(bias: f32) -> bool {
	assert(bias >= 0, "coin-flip bias must be positive")
	assert(bias <= 1, "coin-flip bias must be <=1")
	return rand.float32() < bias
}

// TODO status/living/dead restrictions
random_target_relative :: proc(
	k: Skill_Name,
	ally_team: Maybe(int),
	target_all_prob: f32 = .5,
) -> (
	target: Target_Selection,
	valid: bool,
) {
	skill := skills[k]
	target_type := skill.targeting

	ally_team := ally_team.? or_else (coinflip(.5) ? PLAYER_TEAM : BADDY_TEAM)
	opponent_team := 1 - ally_team

	switch target_type {
	case .One_Opponent:
		switch opponent_team {
		case PLAYER_TEAM:
			target, valid = random_ally_target().?
		case BADDY_TEAM:
			target, valid = random_baddy_target().?
		}
	case .Some_Opponents:
		if opponent_team == PLAYER_TEAM {
			if coinflip(target_all_prob) {
				target, valid = Target_All_Allies{}, true
			} else {
				target, valid = random_ally_target().?
			}
		} else if opponent_team == BADDY_TEAM {
			if coinflip(target_all_prob) {
				target, valid = Target_All_Baddies{}, true
			} else {
				target, valid = random_baddy_target().?
			}
		}
	case .All_Opponents:
		target = opponent_team == PLAYER_TEAM ? Target_All_Allies{} : Target_All_Baddies{}
		valid = true

	case .One_Ally:
		if ally_team == PLAYER_TEAM {
			target, valid = random_ally_target().?
		} else if ally_team == BADDY_TEAM {
			target, valid = random_baddy_target().?
		}
	case .Some_Allies:
		if ally_team == PLAYER_TEAM {
			if coinflip(target_all_prob) {
				target, valid = Target_All_Allies{}, true
			} else {
				target, valid = random_ally_target().?
			}
		} else if ally_team == BADDY_TEAM {
			if coinflip(target_all_prob) {
				target, valid = Target_All_Baddies{}, true
			} else {
				target, valid = random_baddy_target().?
			}
		}
	case .All_Allies:
		target = ally_team == PLAYER_TEAM ? Target_All_Allies{} : Target_All_Baddies{}
		valid = true
	case .One_Combatant:
		target, valid = random_combatant_target().?
	case .All_Combatants:
		target, valid = Target_All_Combatants{}, true
	}
	return
}
