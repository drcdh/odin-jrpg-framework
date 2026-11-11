package game

import "core:log"
import "core:math/rand"

Target_Selection :: union {
	Target_One_Baddy,
	Target_One_Player,
	Target_All_Baddies,
	Target_All_Players,
	Target_All,
}
Target_One_Baddy :: struct {
	i: int,
}
Target_One_Player :: struct {
	i: int,
}
Target_All_Players :: struct {
	prev: int,
}
Target_All_Baddies :: struct {
	prev: int,
}
Target_All :: struct {}

random_player_target :: proc() -> (target: Maybe(Target_One_Player)) {
	targets: [dynamic]int
	defer delete(targets)
	for c_idx, player_idx in battle.players {
		if alive(battle.combatants[c_idx]^) {
			append(&targets, player_idx)
		}
	}
	if len(targets) > 0 {
		target = Target_One_Player{rand.choice(targets[:])}
	}
	return
}

random_baddy_target :: proc() -> (target: Maybe(Target_One_Baddy)) {
	targets: [dynamic]int
	defer delete(targets)
	for c_idx, baddy_idx in battle.baddies {
		if alive(battle.combatants[c_idx]^) {
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
		if alive(c^) {
			append(&targets, c_idx)
		}
	}
	if len(targets) > 0 {
		target_c_idx := rand.choice(targets[:])
		if battle.combatants[target_c_idx].team == .Player {
			for c_idx, player_idx in battle.players {
				if c_idx == target_c_idx do return Target_One_Player{player_idx}
			}
		} else if battle.combatants[target_c_idx].team == .Baddy {
			for c_idx, baddy_idx in battle.baddies {
				if c_idx == target_c_idx do return Target_One_Baddy{baddy_idx}
			}
		}
	}
	return
}

coinflip :: proc(bias: f32 = .5) -> bool {
	assert(bias >= 0, "coinflip bias must be positive")
	assert(bias <= 1, "coinflip bias must be <=1")
	return rand.float32() < bias
}

// TODO status/living/dead restrictions
random_target :: proc(
	k: Skill_Name,
	team: Team,
	target_all_prob: f32 = .5,
) -> (
	target: Target_Selection,
	valid: bool,
) {
	skill := skills[k]
	offensive := skill.offensive
	target_type := skill.targeting

	target_team := opposite_team(team) if offensive else team

	switch target_type {
	case .One:
		switch target_team {
		case .Player:
			target, valid = random_player_target().?
		case .Baddy:
			target, valid = random_baddy_target().?
		case .None:
			target, valid = random_combatant_target().?
		}
	case .Some:
		if coinflip() {
			// target whole team
			switch target_team {
			case .Player:
				target, valid = Target_All_Players{}, true
			case .Baddy:
				target, valid = Target_All_Baddies{}, true
			case .None:
				target, valid = coinflip() ? Target_All_Players{} : Target_All_Baddies{}, true
			}
		} else {
			switch target_team {
			case .Player:
				target, valid = random_player_target().?
			case .Baddy:
				target, valid = random_baddy_target().?
			case .None:
				target, valid = random_combatant_target().?
			}
		}
	case .Team:
		switch target_team {
		case .Player:
			target, valid = Target_All_Players{}, true
		case .Baddy:
			target, valid = Target_All_Baddies{}, true
		case .None:
			target, valid = coinflip() ? Target_All_Players{} : Target_All_Baddies{}, true
		}
	case .All:
		target, valid = Target_All{}, true
	}
	return
}

target_update :: proc(dx, dy: int, ts: Target_Selection, tt: Target_Type) -> Target_Selection {
	switch ts in ts {
	case Target_One_Baddy:
		if dy != 0 {
			return Target_One_Baddy{change_baddy_selection(ts.i, dy)}
		} else if dx < 0 && tt != .One {
			return Target_All_Baddies{ts.i}
		} else if dx > 0 {
			return Target_One_Player{}
		}
	case Target_All_Baddies:
		if dx > 0 && tt != .Team {
			return Target_One_Baddy{ts.prev}
		}
	case Target_One_Player:
		if dy != 0 {
			return Target_One_Player{change_player_selection(ts.i, dy)}
		} else if dx > 0 && tt != .One {
			return Target_All_Players{ts.i}
		} else if dx < 0 { // TODO: check for ally_only/consent
			return Target_One_Baddy{}
		}
	case Target_All_Players:
		if dx < 0 && tt != .Team {
			return Target_One_Player{ts.prev}
		}
	case Target_All:
	// do nothing
	}
	return ts
}

default_target_selection :: proc(tt: Target_Type, offensive: bool) -> (ts: Target_Selection) {
	// This assumes that the player is in control
	switch tt {
	case .One:
		ts = offensive ? Target_One_Baddy{select_first_baddy()} : Target_One_Player{}
	case .Some:
		ts = offensive ? Target_One_Baddy{select_first_baddy()} : Target_One_Player{}
	case .Team:
		ts = offensive ? Target_All_Baddies{} : Target_All_Players{}
	case .All:
		ts = Target_All{}
	}
	return
}

select_first_baddy :: proc() -> int {
	return change_baddy_selection(MAX_ENCOUNTER_SIZE, 1)
}

change_player_selection :: proc(t, d: int) -> int {
	target := t + d
	if target < 0 {target = len(battle.players) - 1}
	if target >= len(battle.players) {target = 0}
	return target
}

change_baddy_selection :: proc(t, d: int) -> int {
	aaah: int
	initial_target := t
	target := t + d
	for {
		if aaah += 1; aaah > 10 {
			log.error("infinite loop?!")
			break // FIXME
		}
		if target < 0 {target = len(battle.baddies) - 1}
		if target >= len(battle.baddies) {target = 0}
		if target == initial_target {break}
		if alive(battle.combatants[battle.baddies[target]]^) {break}
		target += d
	}
	return target
}

get_single_target :: proc(target_selection: Target_Selection) -> (target_idx: int, ok: bool) #optional_ok {
	#partial switch ts in target_selection {
	case Target_One_Baddy:
		target_idx, ok = battle.baddies[ts.i], true
	case Target_One_Player:
		target_idx, ok = battle.players[ts.i], true
	}
	assert(ok, "get_single_target got other than Target_One_Baddy or Target_One_Player")
	if !ok do log.errorf("get_single_target got %v", target_selection)
	return
}

get_team_target :: proc(target_selection: Target_Selection) -> (team: Team, ok: bool) #optional_ok {
	#partial switch ts in target_selection {
	case Target_All_Baddies:
		team, ok = .Baddy, true
	case Target_All_Players:
		team, ok = .Player, true
	}
	assert(ok, "get_team_target got other than Target_All_Baddies or Target_All_Players")
	if !ok do log.errorf("get_team_target got %v", target_selection)
	return
}
