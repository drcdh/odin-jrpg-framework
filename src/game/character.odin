package game

import "core:log"
import "core:math"
import "core:math/rand"

Character :: struct {
	base_stats:    Stats,
	exp_to_next:   Maybe(int),
	hitpoints:     int,
	level:         int,
	leveled_stats: Stats,
	name:          string,
	equipment:     Equipment,
	eq_stats:      Stats,
	stats:         Stats,
	statuses:      Statuses,
	skill_set:     Skill_Set,
	skills:        Charged_Skills,
	eid:           Entity_Id,
	// battle stuff
	charge:        Charge, // charge to get turn
	controller:    ^Character, // TODO: will become part of status struct data
	team:          Team,
	windup:        bool, // TODO: change to Maybe(Skill_Play_Id)
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
	c.stats = effective_stats(c.eq_stats, c.statuses)
	c.hitpoints = min(c.hitpoints, int(get_stat(c^, .Hitpoints)))
	set_all_skills() // FIXME
}

instakill :: proc(c: ^Character) {
	c.hitpoints = 0
	remove_all_statuses(c)
}

take_damage :: proc(c: ^Character, hp_loss: int) {
	c.hitpoints = max(0, c.hitpoints - hp_loss)
	if c.hitpoints == 0 {
		remove_all_statuses(c)
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

character_battle_tick :: proc(c: ^Character) {
	if downed(c^) do return
	if winding_up(c^) do return
	if has_any_status(c^, .Paralyze, .Sleep) do return

	ticks := (BATTLE_SPEED*BATTLE_TICK_TIME) * f32(get_stat(c^, .Speed))/SPEED_PAR

	migraine := has_status(c^, .Migraine)
	sprain   := has_status(c^, .Sprain)
	charge_skills(&c.skills, ticks, battle = true, migraine = migraine, sprain = sprain)

	if has_status(c^, .Slow) do ticks *= .5
	if has_status(c^, .Haste) do ticks *= 1.5
	update_charge(&c.charge, ticks)
}

new_character_charge :: proc(c: Character) -> Charge {
	max: Ticks = 100
	value: Ticks = f32(get_stat(c, .Speed))*rand.float32_uniform(.5, 1)
	return new_charge(max=max, value=value)
}

reset_character_charge :: proc(c: ^Character, max: Ticks = DEFAULT_CHARGE_MAX) {
	reset_charge(&c.charge, max)
	log.infof("%s charge reset with max=%f", c.name, max)
}
