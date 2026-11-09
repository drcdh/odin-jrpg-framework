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
	Overheat,   // O
	Paralyze,   // P
	Poison,     // p
	Rage,       // R
	Regen,      // G
	Sick,       // s
	Sleep,      // S
	Slow,       // W
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
	.Overheat   = "O",
	.Paralyze   = "P",
	.Poison     = "p",
	.Rage       = "R",
	.Regen      = "G",
	.Sick       = "s",
	.Sleep      = "S",
	.Slow       = "W",
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
	update_character_sprite(c^)
}

add_status :: proc {
	add_status_Character,
	add_status_Statuses,
}

remove_status_Statuses :: proc(statuses: ^Statuses, status: Status_Name) {
	statuses[status] = false
}

remove_status_Character :: proc(c: ^Character, status: Status_Name) {
	remove_status_Statuses(&c.statuses, status)
	// only a Character controlled in battle has a controller
	if status == .Control && c.controller != nil {
		controller := c.controller // TODO: extract from status struct data
		c.controller = nil
		remove_status(controller, .Controller)
	}
	update_character_sprite(c^)
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
	case .Overheat:
	case .Paralyze:
		// remove_status(statuses, .Controller) // ?
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
