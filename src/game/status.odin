package game

import "core:strings"

Status_Name :: enum {
	Berserk,    // k
	Blind,      // B
	Confuse,    // C
	Control,    // c
	Controller, //
	Haste,      // H
	Migraine,   // M
	Paralyze,   // P
	Poison,     // p
	Rage,       // R
	Regen,      // G
	Sick,       // s
	Sleep,      // S
	Slow,       // W
	Sprain,     // a
	Zombie,     // Z
}

@(rodata)
status_glyph_keys := [Status_Name]string {
	.Berserk    = "k",
	.Blind      = "B",
	.Confuse    = "C",
	.Control    = "c",
	.Controller = " ",
	.Haste      = "H",
	.Migraine   = "M",
	.Paralyze   = "P",
	.Poison     = "p",
	.Rage       = "R",
	.Regen      = "G",
	.Sick       = "s",
	.Sleep      = "S",
	.Slow       = "W",
	.Sprain     = "a",
	.Zombie     = "Z",
}

Statuses :: [Status_Name]bool

statuses_string_Statuses :: proc(statuses: Statuses, width: int = 0) -> cstring {
	s: string
	for st in Status_Name {
		if st == .Controller do continue
		if statuses[st] do s = strings.concatenate({s, status_glyph_keys[st]}, context.temp_allocator)
		if width > 0 && len(s) == width do s = strings.concatenate({s, "\n"}, context.temp_allocator)
	}
	return strings.clone_to_cstring(s, context.temp_allocator)
}

statuses_string_Character :: proc(c: Character, width: int = 0) -> cstring {
	return statuses_string_Statuses(c.statuses, width)
}

statuses_string :: proc {
	statuses_string_Character,
	statuses_string_Statuses,
}

add_status_Statuses :: proc(statuses: ^Statuses, status: Status_Name) {
	statuses[status] = true
	cancel_statuses(statuses, status)
}

add_status_Character :: proc(c: ^Character, status: Status_Name) {
	add_status_Statuses(&c.statuses, status)
	set_effective_stats(c)
	if status == .Berserk || status == .Confuse || status == .Control || status == .Paralyze || status == .Rage || status == .Sleep || status == .Zombie {
		reset_character_charge(c)
		interrupt_windup(c)
	}
}

add_status :: proc {
	add_status_Character,
	add_status_Statuses,
}

remove_status_Statuses :: proc(statuses: ^Statuses, status: Status_Name) {
	statuses[status] = false
}

remove_status_Character :: proc(c: ^Character, status: Status_Name) {
	if !has_status(c^, status) do return
	remove_status_Statuses(&c.statuses, status)
	set_effective_stats(c)
	// only a Character controlled in battle has a controller
	if status == .Control && c.controller != nil {
		controller := c.controller // TODO: extract from status struct data
		c.controller = nil
		remove_status(controller, .Controller)
	} else if status == .Controller {
		// TODO: extract from status struct data
		// find controlled character
		for other in battle.combatants {
			if has_status(other^, .Control) && other.controller == c do remove_status(other, .Control)
			reset_character_charge(other)
		}
	}
}

remove_status :: proc {
	remove_status_Character,
	remove_status_Statuses,
}

has_status_Statuses :: proc(statuses: Statuses, status: Status_Name) -> bool {
	return statuses[status]
}

has_status_Character :: proc(c: Character, status: Status_Name) -> bool {
	return has_status_Statuses(c.statuses, status)
}

has_status :: proc {
	has_status_Character,
	has_status_Statuses,
}

has_any_status :: proc(c: Character, statuses: ..Status_Name) -> bool {
	for status in statuses {
		if has_status(c, status) do return true
	}
	return false
}

remove_all_statuses :: proc(c: ^Character) {
	for status in Status_Name {
		remove_status(c, status)
	}
}

cancel_statuses :: proc(statuses: ^Statuses, status: Status_Name) {
	switch status {
	case .Berserk:
		remove_status(statuses, .Control)
		remove_status(statuses, .Controller)
	case .Blind:
	case .Confuse:
		remove_status(statuses, .Control)
		remove_status(statuses, .Controller)
		remove_status(statuses, .Rage)
	case .Control:
		remove_status(statuses, .Confuse)
		remove_status(statuses, .Controller)
	case .Controller:
	case .Haste:
		remove_status(statuses, .Slow)
	case .Migraine:
	case .Paralyze:
		remove_status(statuses, .Controller)
	case .Poison:
	case .Rage:
		remove_status(statuses, .Berserk)
		remove_status(statuses, .Controller)
	case .Regen:
	case .Sick:
	case .Sleep:
		remove_status(statuses, .Berserk)
		remove_status(statuses, .Confuse)
		remove_status(statuses, .Control)
		remove_status(statuses, .Controller)
		remove_status(statuses, .Rage)
	case .Slow:
		remove_status(statuses, .Haste)
	case .Sprain:
	case .Zombie:
		remove_status(statuses, .Berserk)
		remove_status(statuses, .Confuse)
		remove_status(statuses, .Control)
		remove_status(statuses, .Controller)
		remove_status(statuses, .Migraine)
		remove_status(statuses, .Rage)
		remove_status(statuses, .Regen)
		remove_status(statuses, .Sick)
		remove_status(statuses, .Sleep)
	}
}

can_take_turn :: proc(c: Character) -> bool {
	return !has_any_status(c,
		.Paralyze,
		.Sleep,
	)
}

is_uncontrollable :: proc(c: Character) -> bool {
	return has_any_status(c,
		.Berserk,
		.Confuse,
		.Paralyze,
		.Rage,
		.Sleep,
		.Zombie,
	)
}

migraine_sprain_modify_charge :: proc(ticks: Ticks, k: Skill_Name, migraine, sprain: bool) -> Ticks {
	// TODO: affect charge as a function of phys/psy power balance
	ticks := ticks
	if is_physical_skill(k) && sprain   do ticks *= .75
	if is_psychic_skill(k)  && migraine do ticks *= .75
	return ticks
}

status_stat_modifier :: proc(status_name: Status_Name, stat_name: Stat_Name) -> Stat {
	switch status_name {
	case .Berserk:
		if stat_name == .Vigor        do return 1.5
		if stat_name == .Psy_Power    do return 0.25
		if stat_name == .Psy_Defense  do return 0.5
	case .Blind:
		if stat_name == .Evasion      do return 0.25
	case .Confuse:
		if stat_name == .Psy_Defense  do return 0.5
	case .Control:
	case .Controller:
	case .Haste:
		if stat_name == .Speed        do return 1.5
	case .Migraine:
	case .Paralyze:
		if stat_name == .Evasion      do return 0.
	case .Poison:
	case .Rage:
		if stat_name == .Psy_Power    do return 1.5
		if stat_name == .Weapon_Power do return 1.5
	case .Regen:
	case .Sick:
	case .Sleep:
		if stat_name == .Evasion      do return 0.
		if stat_name == .Psy_Defense  do return 0.1
	case .Slow:
		if stat_name == .Speed        do return 0.5
	case .Sprain:
		if stat_name == .Evasion      do return 0.5
	case .Zombie:
		if stat_name == .Evasion      do return 0.1
		if stat_name == .Psy_Power    do return 0.
		if stat_name == .Psy_Defense  do return 0.
	}
	return 1.
}

statuses_stat_modifier :: proc(statuses: Statuses, stat_name: Stat_Name) -> (m: Stat) {
	m = 1
	for status_name in Status_Name {
		if statuses[status_name] do m *= status_stat_modifier(status_name, stat_name)
	}
	return
}

interstatus_accuracy_mod :: proc(target: Character, s: Status_Name) -> Stat {
	m := Stat(1)
	if has_status(target, .Berserk) {
		if s == .Confuse  do m *= 1.25
	}
	if has_status(target, .Confuse) {
		if s == .Berserk  do m *= 1.25
		if s == .Sleep    do m *= 1.25
	}
	if has_status(target, .Control) {
		if s == .Confuse  do m *= 1.25
	}
	if has_status(target, .Migraine) {
		if s == .Confuse  do m *= 1.25
		if s == .Control  do m *= 1.25
	}
	if has_status(target, .Rage) {
		if s == .Berserk  do m *= 0
		if s == .Confuse  do m *= 0.25
		if s == .Control  do m *= 0.25
		if s == .Sleep    do m *= 0.25
	}
	if has_status(target, .Sleep) {
		if s == .Berserk  do m *= 0
		if s == .Confuse  do m *= 0
		if s == .Control  do m *= 0
		if s == .Rage     do m *= 0
	}
	if has_status(target, .Zombie) {
		if s == .Berserk  do m *= 0
		if s == .Confuse  do m *= 0
		if s == .Control  do m *= 0
		if s == .Migraine do m *= 0
		if s == .Rage     do m *= 0
		if s == .Regen    do m *= 0
		if s == .Sick     do m *= 0
		if s == .Sleep    do m *= 0
	}
	return m
}
