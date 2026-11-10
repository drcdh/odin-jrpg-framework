package game

Target_Type :: enum {
	One,
	Some, // one combatant or one entire team
	Team, // one entire team
	All,
}

Skill :: struct {
	name:        string,
	effect_data: Effect_Data,
	effect_type: Effect_Type,
	targeting:   Target_Type,
	offensive:   bool,
	// ally_only:   bool,
	windup:      int,
	cost:        int,
	cooldown:    int,
	animation:   Sprite_Name,
	sound:       Sound_Name,
	description: string,
}

Skill_Set :: bit_set[Skill_Name]

Charged_Skill :: struct {
	charge: Charge,
	skill:  Skill_Name,
}

Charged_Skills :: [dynamic]Charged_Skill

new_charged_skills :: proc(skill_set: Skill_Set) -> (cs: Charged_Skills) {
	for k in skill_set {
		append(&cs, Charged_Skill{skill = k, charge = new_charge(max=Ticks(skills[k].cooldown))})
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
		append(cs, Charged_Skill{skill = k, charge = new_charge(max=Ticks(skills[k].cooldown))})
	}
}

charge_skill :: proc(cs: ^Charged_Skill, ticks: Ticks, migraine, sprain: bool, battle := false) {
	k := cs.skill
	if skills[k].cooldown == 0 do return // cantrip
	if battle { 	//|| k.world {
		ticks := ticks
		// TODO: affect charge as a function of phys/psy power balance
		if is_physical_skill(k) && sprain   do ticks *= .75
		if is_psychic_skill(k)  && migraine do ticks *= .75
		update_charge(&cs.charge, ticks)
	}
}

charge_skills :: proc(cs: ^Charged_Skills, ticks: Ticks, migraine, sprain: bool, battle := false) {
	for &_cs in cs {
		charge_skill(&_cs, ticks, migraine, sprain, battle)
	}
}

is_physical_skill :: proc(k: Skill_Name) -> bool {
	return skills[k].effect_data.power > 0
}

is_psychic_skill :: proc(k: Skill_Name) -> bool {
	return skills[k].effect_data.psy_power > 0
}

is_world_skill :: proc(skill_name: Skill_Name) -> (is: bool) {
	return !skills[skill_name].offensive
}

// `actor` is nil for an item.
do_skill :: proc(actor, target: ^Character, skill: Skill) -> Effect_Result {
	return do_effect(actor, target, skill.effect_data, skill.effect_type)
}

// Does the skill and shows the result right away at the target's entity: the
// sound, the target's new look and the popups. `actor` is nil for an item.
// The battle shows its results later, in show_skill_results.
use_skill :: proc(actor, target: ^Character, skill_name: Skill_Name) -> (r: Effect_Result) {
	skill := skills[skill_name]
	r = do_skill(actor, target, skill)
	play_sound(skill.sound)
	update_character_sprite(target^)
	show_effect_popups(target^, r)
	return
}
