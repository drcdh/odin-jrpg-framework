package rules

import "core:fmt"
import "core:os"
import "core:testing"

// Headless: no window, no clock. The rules keep their state in package
// globals, so run with ODIN_TEST_THREADS=1.

@(test)
equipping_a_knife_takes_it_from_the_inventory_and_grants_skills :: proc(t: ^testing.T) {
	init_new_game(); defer destroy()
	pc := &playable_characters[0]
	testing.expect(t, .Slash not_in pc.skill_set, "bare hands shouldn't slash")

	character_set_equipped_item(pc, .Mainhand, .Knife)
	testing.expect_value(t, equipped_item(pc.equipment, Equipment_Slot.Mainhand), Item_Name.Knife)
	testing.expect_value(t, game_data.inventory[Item_Name.Knife], 0)
	testing.expect(t, Skill_Set{.Slash, .Stab} <= pc.skill_set, "a knife should grant Slash and Stab")

	character_set_equipped_item(pc, .Mainhand, .None)
	testing.expect_value(t, game_data.inventory[Item_Name.Knife], 1)
	testing.expect(t, .Slash not_in pc.skill_set, "unequipping should take Slash away")
}

@(test)
save_and_load_restore_the_party :: proc(t: ^testing.T) {
	FILE :: "rules_test.json"
	init_new_game(); defer destroy()
	defer os.remove(fmt.tprintf("%s/%s", SAVE_DIR, FILE))

	pc := &playable_characters[0]
	character_set_equipped_item(pc, .Mainhand, .Knife)
	set_level(pc, 3)
	pc.hitpoints = 7
	game_data.money = 123
	testing.expect(t, save_game({level = .Grove_Main, tile = {4, 5}}, 0, FILE))

	character_set_equipped_item(pc, .Mainhand, .None)
	set_level(pc, 1)
	pc.hitpoints = 1
	game_data.money = 0

	sp, ok := load_game(FILE)
	testing.expect(t, ok)
	testing.expect_value(t, sp, Save_Point{level = .Grove_Main, tile = {4, 5}})
	pc = &playable_characters[0]
	testing.expect_value(t, equipped_item(pc.equipment, Equipment_Slot.Mainhand), Item_Name.Knife)
	testing.expect_value(t, pc.level, 3)
	testing.expect_value(t, pc.hitpoints, 7)
	testing.expect_value(t, pc.name, "One")
	testing.expect_value(t, game_data.money, 123)
	testing.expect(t, .Slash in pc.skill_set, "skills follow the loaded equipment")
}
