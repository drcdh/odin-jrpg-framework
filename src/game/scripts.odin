package game

import "core:fmt"
import "core:log"

// this gets called inside a trigger script, so stuff can block
items_in_a_box :: proc(self: Entity_Id, datum: Chest_Datum, items: ..Item_Name, money: Money = 0) {
	set_game_data(datum, true)
	clear_trigger(self)
	set_sprite_tag_of(self, .Opened)
	if len(items) == 0 && money <= 0 {
		say("Ooh, nothing!")
	} else {
		if len(items) > 0 do get_items(..items)
		if money > 0 do get_money(money)
	}
}

// this gets called inside a trigger script, so stuff can block
monster_in_a_box :: proc(self: Entity_Id, datum: Chest_Datum, encounter: Encounter_Name, items: ..Item_Name, money: Money = 0) {
	log.infof("monster-in-a-box %v encounter %v", datum, encounter)
	set_game_data(datum, true)
	clear_trigger(self)
	set_sprite_tag_of(self, .Opened)
	say("Monster in a box!")
	start_encounter(encounter)
	wait_battle()
	pause(.5) // wait for fade_screen in show_skill_results
	log.infof("monster-in-a-box %v items %v", datum, items)
	// say nothing if no items in this case
	if len(items) > 0 do get_items(..items)
	if money > 0 do get_money(money)
}

// should get called inside a script, so stuff can block
start_encounter :: proc(name: Encounter_Name) {
	log.infof("starting encounter %v", name)
	fade_screen(1, .25)
	encounter_init(name) // sets battle.active = true
	play_music(.Battle)
	fade_screen(0, .25)
	pause(.25)
	battle.paused = false
}

character_get_experience :: proc(pc_idx, exp: int) {
	c := &playable_characters[pc_idx]
	log.infof("%s gets experience %d", c.name, exp)
	prev_level := c.level
	new_skills: Skill_Set
	for exp := exp; exp > 0; {
		log.infof("%s gets %d exp to next level", c.name, exp)
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

	if c.level > prev_level {
		say(fmt.tprintf("%s got to level %d", c.name, c.level))
		for k in new_skills {
			say(fmt.tprintf("%s learned %s", c.name, skills[k].name))
		}
	}
}

party_get_experience :: proc(exp: int) {
	log.infof("party gets experience %d", exp)
	say(fmt.tprintf("Got %d experience points", exp))

	for pc_idx in 0 ..< NUM_PC {
		if !game_data.party_membership[pc_idx] do continue
		character_get_experience(pc_idx, exp)
	}
}
