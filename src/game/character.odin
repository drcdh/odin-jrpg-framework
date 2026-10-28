package rules

import "core:log"
import "core:math"
import "core:strings"

Character :: struct {
	base_stats:    Stats,
	exp_to_next:   Maybe(int),
	hitpoints:     int,
	level:         int,
	leveled_stats: Stats,
	name:          string,
	equipment:     Equipment,
	eq_stats:      Stats,
	stats:         Stats, // after status
	using status:  Status,
	skill_set:     Skill_Set,
	skills:        Charged_Skills,
}

alive :: proc(c: Character) -> bool {
	return c.hitpoints > 0
}

downed :: proc(c: Character) -> bool {
	return c.hitpoints <= 0
}

exp_to_next :: proc(level: int) -> Maybe(int) {
	if level >= MAX_LEVEL {
		return nil
	}
	return 1 * int(math.pow(f32(level), 2.5))
}

set_level :: proc(c: ^Character, level: int) {
	log.infof("%s went to level %d", c.name, level)
	c.exp_to_next = exp_to_next(level)
	c.level = level
	set_leveled_stats(c)
}

set_leveled_stats :: proc(c: ^Character) {
	c.leveled_stats = leveled_stats(c.level, c.base_stats)
	set_eq_stats(c)
}

set_eq_stats :: proc(c: ^Character) {
	c.eq_stats = equipped_stats(c.leveled_stats, c.equipment)
	set_all_skills()
	set_effective_stats(c)
}

set_effective_stats :: proc(c: ^Character) {
	c.stats = effective_stats(c.eq_stats, c.status)
	c.hitpoints = min(c.hitpoints, int(get_stat(c^, .Hitpoints)))
	set_all_skills() // FIXME
}

instakill :: proc(c: ^Character) {
	c.hitpoints = 0
	remove_all_status(c)
}

take_damage :: proc(c: ^Character, hp_loss: int) {
	c.hitpoints = max(0, c.hitpoints - hp_loss)
	if c.hitpoints == 0 {
		remove_all_status(c)
	}
}

take_poison_damage :: proc(c: ^Character) -> int {
	dmg := int(.5 + get_stat(c^, .Hitpoints) / 20)
	take_damage(c, dmg)
	return dmg
}

gain_level :: proc(c: ^Character) -> Skill_Set {
	log.infof("%s gained a level", c.name)
	prev_skill_set := c.skill_set
	set_level(c, c.level + 1)
	new_skills := c.skill_set - prev_skill_set
	for k in new_skills {
		log.infof("%s learned %s", c.name, skills[k].name)
	}
	return new_skills
}

character_get_experience :: proc(c: ^Character, exp: int) -> (new_skills: Skill_Set) {
	for exp := exp; exp > 0; {
		log.infof("%s gets %d exp", c.name, exp)
		if exp_needed, ok := c.exp_to_next.(int); ok {
			if exp >= exp_needed {
				new_skills |= gain_level(c)
				exp -= exp_needed
			} else {
				c.exp_to_next = exp_needed - exp
				exp = 0
			}
		}
	}
	return
}

// party_get_experience :: proc(exp: int) {
// 	if exp <= 0 do return
// 	for party_idx in 0 ..< party_size() {
// 		pc := get_party_member(party_idx)
// 		get_experience(pc, exp)
// 	}
// }

Status_Name :: enum {
	Confuse,
	Control,
	Poison,
	Zombie,
}

Status :: struct {
	confuse: bool,
	control: bool,
	poison:  bool,
	zombie:  bool,
}

get_status_cstring :: proc(status: Status) -> cstring {
	s := ""
	if status.poison {
		s = strings.concatenate({s, "P"}, context.temp_allocator)
	}
	if status.zombie {
		s = strings.concatenate({s, "Z"}, context.temp_allocator)
	}
	return strings.clone_to_cstring(s, context.temp_allocator)
}

add_status :: proc(c: ^Character, status: Status_Name) {
	switch status {
	case .Confuse:
		c.confuse = true
	case .Control:
		c.control = true
	case .Poison:
		c.poison = true
	case .Zombie:
		c.zombie = true
	}
	// add_text_effect(c^, fmt.caprintf("%s", status), rl.PURPLE)
}

remove_status :: proc(c: ^Character, status: Status_Name) {
	switch status {
	case .Confuse:
		c.confuse = false
	case .Control:
		c.control = false
	case .Poison:
		c.poison = false
	case .Zombie:
		c.zombie = false
	}
	// add_text_effect(c, fmt.caprintf("Cured"))
}

remove_all_status :: proc(c: ^Character) {
	for status in Status_Name {
		remove_status(c, status)
	}
}

character_set_equipped_item :: proc(
	character: ^Character,
	slot: Equipment_Slot,
	item: Item_Name,
	from_inventory := true,
	to_inventory := true,
) {
	set_equipped_item(&character.equipment, slot, item, from_inventory, to_inventory)
	set_eq_stats(character)
}

character_unequip_all :: proc(character: ^Character, to_inventory := true) {
	unequip_all(&character.equipment, to_inventory)
	set_eq_stats(character)
}
