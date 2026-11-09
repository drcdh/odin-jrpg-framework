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
	// PCs carry these over from the last battle
	c.ticks = 0
	c.windup = false
	c.controller = nil
	update_character_sprite(c^)
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
		add_combatant(new_baddy(baddy_templates[baddy_id]))
	}
	for pc_idx in 0 ..< NUM_PC {
		if game_data.party_membership[pc_idx] {
			for &cs in playable_characters[pc_idx].skills {
				cs.charge = 0
			}
			add_combatant(&playable_characters[pc_idx])
		}
	}
	battle.encounter = &encounters[name]
}
