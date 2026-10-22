package rules

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

// Headless: no window, no clock. The rules keep their state in package
// globals, so run with ODIN_TEST_THREADS=1.
//
// init_new_game only resets and allocates the globals; each test sets up the
// state it checks, so the tests don't depend on how a new game starts (the
// starting party, inventory and names are content and will change).

// PC 0 with an empty main hand and exactly one Knife in the inventory.
@(private = "file")
setup_bare_handed_pc :: proc() -> ^Character {
	init_new_game()
	pc := &playable_characters[0]
	character_set_equipped_item(pc, .Mainhand, .None, to_inventory = false)
	game_data.inventory[Item_Name.Knife] = 1
	set_inventory_order()
	return pc
}

@(test)
equipping_a_knife_takes_it_from_the_inventory_and_grants_skills :: proc(t: ^testing.T) {
	pc := setup_bare_handed_pc(); defer destroy()
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
	pc := setup_bare_handed_pc(); defer destroy()
	defer os.remove(fmt.tprintf("%s/%s", SAVE_DIR, FILE))

	delete(pc.name)
	pc.name = strings.clone("Tester")
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
	testing.expect_value(t, pc.name, "Tester")
	testing.expect_value(t, game_data.money, 123)
	testing.expect(t, .Slash in pc.skill_set, "skills follow the loaded equipment")
}

@(test)
debug_equippables_floor_stats_and_unequipping_restores_them :: proc(t: ^testing.T) {
	init_new_game(); defer destroy()
	pc := &playable_characters[0]
	// No other gear: percentage modifiers scale only the base stats, so other
	// items' flat bonuses would survive Debug Mul.
	character_unequip_all(pc, to_inventory = false)
	game_data.inventory[Item_Name.Debug_Abs] = 1
	game_data.inventory[Item_Name.Debug_Mul] = 1
	set_inventory_order()

	for item in ([]Item_Name{.Debug_Abs, .Debug_Mul}) {
		original := pc.stats
		testing.expect(t, original[Stat_Name.Hitpoints] > MIN_HITPOINTS, "max hitpoints start at the floor, so the test proves little")

		character_set_equipped_item(pc, .Accessory, item)
		for v, s in pc.stats {
			want := MIN_HITPOINTS if Stat_Name(s) == .Hitpoints else MIN_STAT
			testing.expectf(t, v == want, "%v equipped: %v is %v, want %v", item, Stat_Name(s), v, want)
		}

		character_set_equipped_item(pc, .Accessory, .None)
		testing.expectf(t, pc.stats == original, "%v unequipped: stats %v, want %v", item, pc.stats, original)
	}
}
