package game

import "core:log"

MAX_ENCOUNTER_SIZE :: 6

Encounter_Spot :: struct {
	tile:     [2]int, // position in the baddies' formation
	baddy_id: Baddy_Id, // nil: an empty spot
}

Encounter :: struct {
	baddies: [MAX_ENCOUNTER_SIZE]Encounter_Spot,
	exp:     int,
}

// The baddy's Character is freed in battle_cleanup.
@(private = "file")
baddy_combatant :: proc(template: Baddy_Template) -> Combatant {
	return Combatant{character = new_baddy(template), team = .Baddy}
}

@(private = "file")
player_combatant :: proc(pc_idx: int) -> Combatant {
	return Combatant{character = &playable_characters[pc_idx], team = .Player}
}

@(private = "file")
add_combatant :: proc(c: Combatant) {
	switch c.team {
	case .None:
		panic("Don't know what to do with Combatant with Team.None")
	case .Baddy:
		append(&battle.baddies, len(battle.combatants))
	case .Player:
		append(&battle.players, len(battle.combatants))
	}
	append(&battle.combatants, c)
}

add_combatants_for_encounter :: proc(name: Encounter_Name) {
	for spot in encounters[name].baddies {
		baddy_id := spot.baddy_id
		if baddy_id == .None do continue
		log.infof("adding combatant %s (%v)", baddy_templates[baddy_id].name, baddy_id)
		add_combatant(baddy_combatant(baddy_templates[baddy_id]))
	}
	for pc_idx in 0 ..< NUM_PC {
		if game_data.party_membership[pc_idx] {
			for &cs in playable_characters[pc_idx].skills {
				cs.charge = 0
			}
			add_combatant(player_combatant(pc_idx))
		}
	}
	battle.encounter = &encounters[name]
}
