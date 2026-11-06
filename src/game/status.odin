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

statuses_string_Combatant :: proc(c: Combatant, width: int = 0) -> cstring {
	return statuses_string_Character(c.character^, width)
}

statuses_string :: proc {
	statuses_string_Character,
	statuses_string_Combatant,
	statuses_string_Statuses,
}

add_status_Statuses :: proc(statuses: ^Statuses, status: Status_Name) {
	statuses[status] = true
}

add_status_Character :: proc(c: ^Character, status: Status_Name) {
	add_status_Statuses(&c.statuses, status)
}

add_status_Combatant :: proc(c: ^Combatant, status: Status_Name) {
	add_status_Character(c.character, status)
}

add_status :: proc {
	add_status_Character,
	add_status_Combatant,
	add_status_Statuses,
}

remove_status_Statuses :: proc(statuses: ^Statuses, status: Status_Name) {
	statuses[status] = false
}

remove_status_Character :: proc(c: ^Character, status: Status_Name) {
	remove_status_Statuses(&c.statuses, status)
}

remove_status_Combatant :: proc(c: ^Combatant, status: Status_Name) {
	remove_status_Character(c.character, status)
}

remove_status :: proc {
	remove_status_Character,
	remove_status_Combatant,
	remove_status_Statuses,
}

has_status_Statuses :: proc(statuses: Statuses, status: Status_Name) -> bool {
	return statuses[status]
}

has_status_Character :: proc(c: Character, status: Status_Name) -> bool {
	return has_status_Statuses(c.statuses, status)
}

has_status_Combatant :: proc(c: Combatant, status: Status_Name) -> bool {
	return has_status_Character(c.character^, status)
}

has_status :: proc {
	has_status_Character,
	has_status_Combatant,
	has_status_Statuses,
}

remove_all_statuses :: proc(c: ^Character) {
	for status in Status_Name {
		remove_status(c, status)
	}
}
