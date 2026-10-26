package rules

import "core:fmt"
import "core:log"

READY_TICKS :: 100 // ticks per turn

Ticks :: f32

Combatant :: struct {
	using character: ^Character,
	team:            int,
	ticks:           Ticks,
	windup:          bool,
}

Battle_Skill_Play :: struct {
	actor_idx:  int,
	targets:    Target_Selection,
	skill_name: Skill_Name,
	windup:     Ticks,
}

// Battle_Proc :: proc(start := false, result: Maybe(Battle_Result) = nil) -> bool // return true to do default init/win/lose stuff
// Turn_Proc :: proc(actor_idx: int)

Battle_Result :: enum {
	Lose,
	Win,
}

Battle :: struct {
	allies:      [dynamic]int,
	baddies:     [dynamic]int,
	combatants:  [dynamic]Combatant,
	encounter:   ^Encounter,
	skill_plays: [dynamic]Battle_Skill_Play,
}

autobattle: bool // debug mode

battle: Battle

battle_cleanup :: proc() {
	for c_idx in battle.baddies {
		// free new Characters created with new_baddy in start_encounter
		delete(battle.combatants[c_idx].skills)
		free(battle.combatants[c_idx].character)
	}
	clear(&battle.allies)
	clear(&battle.baddies)
	clear(&battle.combatants)
	clear(&battle.skill_plays)
	battle.encounter = nil
}

battle_destroy :: proc() {
	delete(battle.allies)
	delete(battle.baddies)
	delete(battle.combatants)
	delete(battle.skill_plays)
}

check_win :: proc() -> Maybe(Battle_Result) {
	allies_alive := false
	for c_idx in battle.allies {
		if combatant_alive(battle.combatants[c_idx]) {
			allies_alive = true
		}}
	if !allies_alive {
		return .Lose
	}
	baddies_alive := false
	for c_idx in battle.baddies {
		if combatant_alive(battle.combatants[c_idx]) {
			baddies_alive = true
		}
	}
	if !baddies_alive {
		return .Win
	}
	return nil
}

combatant_alive :: proc(c: Combatant) -> bool {
	return alive(c.character^)
}

combatant_downed :: proc(c: Combatant) -> bool {
	return downed(c.character^)
}

combatant_ready :: proc(c: Combatant) -> bool {
	return c.ticks >= READY_TICKS && combatant_alive(c) && !combatant_winding_up(c)
}

combatant_winding_up :: proc(c: Combatant) -> bool {
	return c.windup
}

battle_tick :: proc() {
	take_turns()

	TICK :: 1 // FIXME
	for &c in battle.combatants {
		if combatant_downed(c) do continue
		if combatant_winding_up(c) do continue
		c.ticks += TICK * f32(get_stat(c, .Speed))
		if c.ticks > READY_TICKS do c.ticks = READY_TICKS
		charge_skills(&c.skills, battle = true)
	}

	// remove invalid Skill_Plays
	for i := 0; i < len(battle.skill_plays); {
		c := battle.combatants[battle.skill_plays[i].actor_idx]
		if !c.windup || !combatant_alive(c) {
			fmt.printfln("removing Battle_Skill_Play %d after combatant interrupted or downed", i)
			unordered_remove(&battle.skill_plays, i)
		} else {
			i += 1
		}
	}

	for &s in battle.skill_plays {
		s.windup -= TICK * f32(get_stat(battle.combatants[s.actor_idx], .Speed))
	}

	for i := 0; i < len(battle.skill_plays); {
		if battle.skill_plays[i].windup <= 0 {
			process_skill_play(battle.skill_plays[i])
			unordered_remove(&battle.skill_plays, i)
			break
		} else {
			i += 1
		}
	}
}

get_next_player_controlled_combatant :: proc(previous: Maybe(int)) -> Maybe(int) {
	if autobattle do return nil // shortcut
	previous: Maybe(int) = previous
	first: Maybe(int)
	for c, c_idx in battle.combatants {
		if combatant_ready(c) {
			if (c.team == BADDY_TEAM && c.control) || (c.team == PLAYER_TEAM && !c.control && !c.confuse) {
				if first == nil do first = c_idx
				if previous == nil do return c_idx
				if previous == c_idx do previous = nil
			}
		}
	}
	return first
}

take_turns :: proc() {
	for combatant, c_idx in battle.combatants {
		if combatant_ready(combatant) {
			if combatant.team == BADDY_TEAM {
				if combatant.confuse {
					default_turn(c_idx, opponent_team = nil)
				} else if combatant.control {
					if autobattle do default_turn(c_idx, opponent_team = PLAYER_TEAM)
				} else {
					default_turn(c_idx, opponent_team = PLAYER_TEAM)
				}
			} else if combatant.team == PLAYER_TEAM {
				if combatant.confuse {
					default_turn(c_idx, opponent_team = nil)
				} else if combatant.control {
					default_turn(c_idx, opponent_team = PLAYER_TEAM)
				} else {
					if autobattle do default_turn(c_idx, opponent_team = BADDY_TEAM)
				}
			}
		}
	}
}

queue_battle_skill :: proc(actor_idx: int, targets: Target_Selection, skill_name: Skill_Name) {
	skill := skills[skill_name]
	battle.combatants[actor_idx].ticks -= Ticks(skill.cost)
	battle.combatants[actor_idx].windup = true
	append(&battle.skill_plays, Battle_Skill_Play{actor_idx, targets, skill_name, Ticks(skill.windup)})
}

process_skill_play :: proc(skill_play: Battle_Skill_Play) {
	fmt.printfln("%#v", skill_play)

	skill := skills[skill_play.skill_name]
	actor := &battle.combatants[skill_play.actor_idx]
	actor.windup = false

	switch targets in skill_play.targets {
	case Target_One_Ally:
		target := &battle.combatants[battle.allies[targets.i]]
		do_skill(actor, target, skill)
	case Target_One_Baddy:
		target := &battle.combatants[battle.baddies[targets.i]]
		do_skill(actor, target, skill)
	case Target_All_Allies:
		for target_idx in battle.allies {
			target := &battle.combatants[target_idx]
			do_skill(actor, target, skill)
		}
	case Target_All_Baddies:
		for target_idx in battle.baddies {
			target := &battle.combatants[target_idx]
			do_skill(actor, target, skill)
		}
	case Target_All_Combatants:
		for &target in battle.combatants {
			do_skill(actor, &target, skill)
		}
	}
}

// Breaks `target`'s windup. Returns false if they weren't winding up.
interrupt_windup :: proc(target: ^Combatant) -> bool {
	if !target.windup {
		log.infof("Tried to interrupt %s but they weren't winding up", target.name)
		return false
	}
	target.windup = false
	log.infof("Break! %s is interrupted", target.name)
	return true
}

roll_for_counter :: proc(actor, target: ^Combatant, risk: f32 = 1) {
}
