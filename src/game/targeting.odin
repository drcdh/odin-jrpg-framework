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

default_target_selection_item_name :: proc(n: Item_Name) -> (ts: Target_Selection) {
	ts = nil
	if k, ok := items[n].data.(Consumable); ok {
		ts = default_target_selection_k(k)
	}
	return
}

default_target_selection_k :: proc(k: Skill_Name) -> (ts: Target_Selection) {
	log.debugf("getting default target selection for %v", k)
	skill := skills[k]
	ts = default_target_selection_tt(skill.targeting, skill.offensive)
	return
}

default_target_selection_tt :: proc(tt: Target_Type, offensive: bool) -> (ts: Target_Selection) {
	// This assumes that the player is in control
	switch tt {
	case .One:
		ts = offensive && battle_active() ? Target_One_Baddy{select_first_baddy()} : Target_One_Player{}
	case .Some:
		ts = offensive && battle_active() ? Target_One_Baddy{select_first_baddy()} : Target_One_Player{}
	case .Team:
		ts = offensive && battle_active() ? Target_All_Baddies{} : Target_All_Players{}
	case .All:
		ts = battle_active() ? Target_All{} : Target_All_Players{}
	}
	return
}

default_target_selection :: proc {
	default_target_selection_item_name,
	default_target_selection_k,
	default_target_selection_tt,
}

select_first_baddy :: proc() -> int {
	return change_baddy_selection(MAX_ENCOUNTER_SIZE, 1)
}

// `t` is a party index (c_idx in battle)
change_player_selection :: proc(t, d: int) -> int {
	n := party_size()
	target := t + d
	if target < 0 {target = n - 1}
	if target >= n {target = 0}
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

target_selection_characters :: proc(target_selection: Target_Selection, targets: ^[dynamic]^Character) {
	assert(len(targets) == 0, "targets should be empty")
	switch ts in target_selection {
	case Target_One_Baddy:
		assert(battle_active(), "battle not active")
		append(targets, battle.combatants[battle.baddies[ts.i]])
	case Target_One_Player:
		append(targets, get_party_member(ts.i))
	case Target_All_Baddies:
		assert(battle_active(), "battle not active")
		for c_idx in battle.baddies {
			append(targets, battle.combatants[c_idx])
		}
	case Target_All_Players:
		for party_idx in 0 ..< party_size() {
			append(targets, get_party_member(party_idx))
		}
	case Target_All:
		if battle_active() {
			for c in battle.combatants {
				append(targets, c)
			}
		} else {
			for party_idx in 0 ..< party_size() {
				append(targets, get_party_member(party_idx))
			}
		}
	}
}

world_target_update :: proc(dx, dy: int, ts: Target_Selection, tt: Target_Type) -> Target_Selection {
	#partial switch ts in ts {
	case Target_One_Player:
		if dx != 0 {
			return Target_One_Player{change_player_selection(ts.i, dx)}
		} else if dy != 0 && tt == .Some {
			return Target_All_Players{ts.i}
		}
	case Target_All_Players:
		if dy != 0 && tt == .Some {
			return Target_One_Player{ts.prev}
		}
	}
	return ts
}
