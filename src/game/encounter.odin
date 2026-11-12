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

@(private = "file")
add_combatant :: proc(c: ^Character) {
	c_idx := len(battle.combatants)
	// make sure playable character stuff is reset
	c.c_idx = c_idx
	c.charge = new_character_charge(c^)
	c.windup = false
	c.controller = nil
	update_character_sprite(c^)
	switch c.team {
	case .None:
		panic("Don't know what to do with Combatant with Team.None")
	case .Baddy:
		append(&battle.baddies, c_idx)
	case .Player:
		assert(c_idx == get_party_idx(c))
		append(&battle.players, c_idx)
	}
	append(&battle.combatants, c)
}

add_combatants_for_encounter :: proc(name: Encounter_Name) {
	// player character c_idx should be equal to their party_idx
	for pc_idx in 0 ..< NUM_PC {
		if game_data.party_membership[pc_idx] {
			for &cs in playable_characters[pc_idx].skills {
				reset_charge(&cs.charge)
			}
			add_combatant(&playable_characters[pc_idx])
		}
	}
	for spot in encounters[name].baddies {
		baddy_id := spot.baddy_id
		if baddy_id == .None do continue
		log.infof("adding combatant %s (%v)", baddy_templates[baddy_id].name, baddy_id)
		add_combatant(new_baddy(baddy_templates[baddy_id]))
	}
	battle.encounter = &encounters[name]
}
