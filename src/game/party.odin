package game

import "core:strings"

NUM_PC :: 6

playable_characters: [NUM_PC]Character

// Frees what the PCs own: their names, skill lists and entities.
delete_pcs :: proc() {
	for &pc in playable_characters {
		destroy_entity(pc.eid)
		delete(pc.name)
		delete(pc.skills)
	}
	playable_characters = {}
}

// HP, Vg, Sp, St, PP, WP, Ar, PD, Ev

// Frees the previous PCs first, so it can run again (new game, load).
init_pcs :: proc() {
	delete_pcs()
	playable_characters = {
		{
			base_stats = {60, 30, 30, 30, 20, 5, 0, 20, 5},
			name = strings.clone("One"),
			equipment = new_equipment(mainhand = .Sword, body = .Shirt, feet = .Boots),
		},
		{
			base_stats = {60, 30, 30, 30, 20, 5, 0, 20, 5},
			name = strings.clone("Two"),
			equipment = new_equipment(mainhand = .Knife, body = .Shirt, feet = .Boots),
		},
		{
			base_stats = {60, 30, 30, 30, 20, 5, 0, 20, 5},
			name = strings.clone("Three"),
			equipment = new_equipment(),
		},
		{
			base_stats = {60, 30, 30, 30, 20, 5, 0, 20, 5},
			name = strings.clone("Four"),
			equipment = new_equipment(),
		},
		{
			base_stats = {60, 30, 30, 30, 20, 5, 0, 20, 5},
			name = strings.clone("Five"),
			equipment = new_equipment(),
		},
		{
			base_stats = {60, 30, 30, 30, 20, 5, 0, 20, 5},
			name = strings.clone("Six"),
			equipment = new_equipment(),
		},
	}
	for &pc in playable_characters do pc.team = .Player
}

// The PC's entity, which shows them in battles and menus. It's spawned hidden
// on first use and persists across levels; delete_pcs destroys it.
pc_entity :: proc(pc_idx: int) -> Entity_Id {
	pc := &playable_characters[pc_idx]
	if !entity_alive(pc.eid) {
		sprite := pc_battle_sprite(pc_idx, COMBATANT_LAYER)
		sprite.hidden = true
		pc.eid = spawn_entity(Entity{name = "pc", sprite = sprite, ghost = true, battle = true, persistent = true})
	}
	update_character_sprite(pc^)
	return pc.eid
}

// Makes sure every party member has an entity, with an up-to-date look.
party_entities_ensure :: proc() {
	party_apply(proc(_, pc_idx: int) { pc_entity(pc_idx) })
}

// Hides the party members' entities (leaving a battle or the world menu).
party_entities_hide :: proc() {
	party_apply(proc(_, pc_idx: int) { set_visible(playable_characters[pc_idx].eid, false) })
}

get_pc_idx :: proc(party_idx: int) -> int {
	i := 0
	for m, pc_idx in game_data.party_membership {
		if m {
			if i == party_idx {
				return pc_idx
			}
			i += 1
		}
	}
	panic("empty party")
}

get_party_member :: proc(party_idx: int) -> ^Character {
	i := 0
	for &c, pc_idx in playable_characters {
		if game_data.party_membership[pc_idx] {
			if i == party_idx {
				return &c
			}
			i += 1
		}
	}
	return nil
}

party_size :: proc() -> int {
	size := 0
	for party_idx in 0 ..< NUM_PC {
		if game_data.party_membership[party_idx] {
			size += 1
		}
	}
	return size
}

get_skill_set :: proc(pc_idx: int, equipment: Equipment, level: int, stats: Stats) -> Skill_Set {
	skill_set: Skill_Set
	mh := equipped_item(equipment, Equipment_Slot.Mainhand)
	if pc_idx == 0 {
		if mh == .Atom_Slicer || mh == .Sword || mh == .Knife {
			if level >= 2 {
				skill_set += {.Pommel_Strike}
			}
		}
	} else if pc_idx == 1 {
		skill_set += {.Mind_Control}
	} else if pc_idx == 2 {
		skill_set += {.Healing_Hymn}
	} else if pc_idx == 3 {
		skill_set += {.Fire, .Frost, .Gust}
	} else if pc_idx == 4 {
		skill_set += {.Heal, .Heal_All, .Tangle}
	} else if pc_idx == 5 {
	}

	return skill_set | get_generic_skill_set(equipment, level, stats)
}

get_generic_skill_set :: proc(equipment: Equipment, level: int, stats: Stats) -> (skill_set: Skill_Set) {
	mh := equipped_item(equipment, Equipment_Slot.Mainhand)
	if mh == .Sword || mh == .Knife || mh == .Atom_Slicer {
		skill_set += {.Slash, .Stab}
		if level >= 3 {
			skill_set += {.Wild_Swing}
		}
		if level >= 10 {
			skill_set += {.Slash_All}
		}
		if mh == .Atom_Slicer {
			skill_set += {.Slash_All, .Super_Hyper_Slash}
		}
	} else if mh == .Nail_Bat {
		skill_set += {.Smash, .Wild_Swing}
		if int(get_stat(stats, .Vigor)) + level >= 60 {
			skill_set += {.Quake_Smash}
		}
	} else if mh == .Basic_Wand {
		skill_set += {.Smack, .Fire}
	} else if mh == .None {
		skill_set += {.Punch, .Tickle}
	}
	return
}

set_skills :: proc(pc_idx: int) {
	pc := &playable_characters[pc_idx]
	pc.skill_set = get_skill_set(pc_idx, pc.equipment, pc.level, pc.eq_stats)
	modify_charged_skills(&pc.skills, pc.skill_set)
}

set_all_skills :: proc() {
	for i in 0 ..< NUM_PC {
		set_skills(i)
	}
}

party_unequip_all :: proc(to_inventory := true) {
	for &pc in playable_characters {
		character_unequip_all(&pc, to_inventory)
	}
}

heal_party :: proc(f: f16 = 1) {
	for pc_idx in 0 ..< NUM_PC {
		pc := &playable_characters[pc_idx]
		pc.hitpoints = int(get_stat(pc^, .Hitpoints) / f)
	}
}

get_party_idx :: proc(character: ^Character) -> (int, bool) {
	party_idx: int
	for pc_idx in 0 ..< NUM_PC {
		if game_data.party_membership[pc_idx] {
			if character == &playable_characters[pc_idx] {
				return party_idx, true
			}
			party_idx += 1
		}
	}
	return -1, false
}

do_party_step_effects :: proc() {
	game_data.steps += 1
	for &pc, pc_idx in playable_characters {
		if game_data.party_membership[pc_idx] {
			if has_status(pc, .Poison) {
				take_poison_damage(&pc)
			}
			charge_skills(&pc.skills, 1, migraine = has_status(pc, .Migraine), sprain = has_status(pc, .Sprain), battle = false)
		}
	}
}

party_apply :: proc(f: proc(_, _: int)) {
	party_idx := 0
	for pc_idx in 0 ..< NUM_PC {
		if game_data.party_membership[pc_idx] {
			f(party_idx, pc_idx)
			party_idx += 1
		}
	}
}
