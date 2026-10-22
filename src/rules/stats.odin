package rules

import "core:fmt"

Stat_Name :: enum {
	Hitpoints,
	Vigor,
	Speed,
	Stamina,
	Psy_Power,
	Weapon_Power,
	Armor,
	Psy_Defense,
	Evasion,
}

NUM_STATS :: len(Stat_Name)

Stat :: f16

Stats :: [NUM_STATS]Stat

@(rodata)
STAT_STRINGS := [NUM_STATS]string{"MaxHP", "Vigor", "Speed", "Tough", "@Pow", "Weap.", "Armor", "@Def", "Evade"}
stat_string :: proc(stats: Stats, stat_name: Stat_Name) -> string {
	return fmt.tprintf("%-5s% 3.0f", STAT_STRINGS[stat_name], stats[stat_name])
}

@(rodata)
STAT_STRINGS_SHORT := [NUM_STATS]string{"MHP", "Vg", "Sp", "St", "@P", "WP.", "Ar", "@D", "Ev"}
stat_string_short :: proc(stats: Stats, stat_name: Stat_Name) -> cstring {
	return fmt.ctprintf("%s:% 3.0f", STAT_STRINGS_SHORT[stat_name], stats[stat_name])
}

get_stat_Stats :: proc(stats: Stats, stat_name: Stat_Name) -> Stat {
	return stats[stat_name]
}

get_stat_Character :: proc(character: Character, stat_name: Stat_Name) -> Stat {
	return get_stat_Stats(character.stats, stat_name)
}

// get_stat_Combatant :: proc(combatant: Combatant, stat_name: Stat_Name) -> Stat {
// 	return get_stat_Character(combatant.character^, stat_name)
// }

get_stat :: proc {
	get_stat_Character,
	// get_stat_Combatant,
	get_stat_Stats,
}

set_stat :: proc(stats: ^Stats, stat_name: Stat_Name, v: Stat) {
	stats[stat_name] = v
}

// `mult` is in percent. No stat drops below its MIN_STATS floor, however
// harsh the modifiers.
get_modded_stats :: proc(base, mult, add: Stats) -> (modded: Stats) {
	modded = base + base * (mult / 100) + add
	for &v, s in modded {
		v = max(v, MIN_STATS[Stat_Name(s)])
	}
	return
}

MAX_LEVEL :: 99

// The lowest each stat can be modded down to. Equipment can cancel weapon
// power, armor and evasion entirely; the rest stay at least 1.
@(rodata)
MIN_STATS := [Stat_Name]Stat {
	.Hitpoints    = 1,
	.Vigor        = 1,
	.Speed        = 1,
	.Stamina      = 1,
	.Psy_Power    = 1,
	.Weapon_Power = 0,
	.Armor        = 0,
	.Psy_Defense  = 1,
	.Evasion      = 0,
}
MAX_LEVEL_F :: f32(99)

leveled_stats :: proc(level: int, base: Stats) -> (leveled: Stats) {
	leveled = base
	leveled[Stat_Name.Hitpoints] +=
		(Stat(level) - 1) * (get_stat(base, .Hitpoints) + get_stat(base, .Vigor) + get_stat(base, .Stamina)) / 5
	// set_stat(&leveled, .Hitpoints, lfunc(level, get_stat(base, .Hitpoints)))
	return
}

equipped_stats :: proc(lstats: Stats, equipment: Equipment) -> Stats {
	add: Stats
	mul: Stats
	for slot in Equipment_Slot {
		item_name := equipped_item(equipment, slot)
		if item_name == .None {continue}
		eq := items[item_name].data.(Equippable) or_continue
		add += eq.stats_add
		mul += eq.stats_mul
	}
	return get_modded_stats(lstats, mul, add)
}

effective_stats :: proc(stats: Stats, status: Status) -> Stats {
	return stats // TODO
}
