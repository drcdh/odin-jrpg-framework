package game

Skill :: struct {
	name:        string,
	effect_data: Effect_Data,
	effect_type: Effect_Type,
	targeting:   Target_Type,
	windup:      int,
	cost:        int,
	cooldown:    int,
	animation:   Sprite_Name,
	sound:       Sound_Name,
	description: string,
}

Charge :: u8
CHARGE_MAX :: 255
CHARGE_DECAY :: 10

Skill_Set :: bit_set[Skill_Name]

Charged_Skill :: struct {
	charge: Charge,
	skill:  Skill_Name,
}

Charged_Skills :: [dynamic]Charged_Skill

new_charged_skills :: proc(skill_set: Skill_Set) -> (cs: Charged_Skills) {
	for k in skill_set {
		append(&cs, Charged_Skill{skill = k})
	}
	return
}

modify_charged_skills :: proc(cs: ^Charged_Skills, new_skill_set: Skill_Set) {
	kept: Skill_Set
	for i := 0; i < len(cs); {
		if cs[i].skill in new_skill_set {
			kept += {cs[i].skill}
			i += 1
		} else {
			unordered_remove(cs, i)
		}
	}

	new_skills := new_skill_set - kept
	for k in new_skills {
		append(cs, Charged_Skill{skill = k})
	}
}

charge_skill :: proc(cs: ^Charged_Skill, battle := false) {
	k := cs.skill
	if battle { 	//|| k.world {
		dc := u8(500 / skills[k].cooldown) if skills[k].cooldown > 0 else CHARGE_MAX
		if CHARGE_MAX - cs.charge <= dc {
			cs.charge = CHARGE_MAX
		} else {
			cs.charge += dc
		}
	}
}

charge_skills :: proc(cs: ^Charged_Skills, battle := false) {
	for &_cs in cs {
		charge_skill(&_cs, battle)
	}
}

is_world_skill :: proc(skill_name: Skill_Name) -> (is: bool) {
	skill := skills[skill_name]
	switch skill.targeting {
	case .One_Opponent:
	case .Some_Opponents:
	case .All_Opponents:
	case .One_Ally:
		is = true
	case .Some_Allies:
		is = true
	case .All_Allies:
		is = true
	case .One_Combatant:
		is = true
	case .All_Combatants:
		is = true
	}
	return
}

// `actor` is nil for an item.
do_skill_character :: proc(actor, target: ^Character, skill: Skill) -> Effect_Result {
	return do_effect_character(actor, target, skill.effect_data, skill.effect_type)
}

do_skill_combatant :: proc(actor, target: ^Combatant, skill: Skill) -> Effect_Result {
	return do_effect_combatant(actor, target, skill.effect_data, skill.effect_type)
}

// do_skill :: proc {
// 	do_skill_character,
// 	do_skill_combatant,
// }
