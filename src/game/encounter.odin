package game

import "core:log"

MAX_ENCOUNTER_SIZE :: 6

Encounter_Spot :: struct {
	tile:     [2]int, // position in the baddies' formation
	baddy_id: Maybe(Baddy_Id), // nil: an empty spot
}

Encounter :: struct {
	baddies: [MAX_ENCOUNTER_SIZE]Encounter_Spot,
	exp:     int,
}

ally_combatant :: proc(pc_idx: int) -> Combatant {
	return Combatant{character = &playable_characters[pc_idx], team = PLAYER_TEAM}
}

// The baddy's Character is freed in battle_cleanup.
baddy_combatant :: proc(template: Baddy_Template) -> Combatant {
	return Combatant{character = new_baddy(template), team = BADDY_TEAM}
}

add_ally_combatant :: proc(ally: Combatant) {
	append(&battle.allies, len(battle.combatants))
	append(&battle.combatants, ally)
}

add_baddy_combatant :: proc(baddy: Combatant) {
	append(&battle.baddies, len(battle.combatants))
	append(&battle.combatants, baddy)
}

start_encounter :: proc(name: Encounter_Name) {
	for spot in encounters[name].baddies {
		baddy_id := spot.baddy_id.? or_continue
		log.infof("adding %s (%v)", baddy_templates[baddy_id].name, baddy_id)
		add_baddy_combatant(baddy_combatant(baddy_templates[baddy_id]))
	}
	for pc_idx in 0 ..< NUM_PC {
		if game_data.party_membership[pc_idx] {
			for &cs in playable_characters[pc_idx].skills {
				cs.charge = 0
			}
			add_ally_combatant(ally_combatant(pc_idx))
		}
	}
	battle.encounter = &encounters[name]
}
