package game

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
	headless_core_init(); defer headless_core_shutdown() // load_save_file spawns a script
	pc := setup_bare_handed_pc(); defer destroy()
	defer os.remove(fmt.tprintf("%s/%s", SAVE_DIR, FILE))

	delete(pc.name)
	pc.name = strings.clone("Tester")
	character_set_equipped_item(pc, .Mainhand, .Knife)
	set_level(pc, 3)
	pc.hitpoints = 7
	game_data.money = 123
	testing.expect(t, save_game({level = Level(0), tile = {4, 5}}, 0, FILE))

	character_set_equipped_item(pc, .Mainhand, .None)
	set_level(pc, 1)
	pc.hitpoints = 1
	game_data.money = 0

	sp, ok := load_save_file(FILE)
	testing.expect(t, ok)
	testing.expect_value(t, sp, Save_Point{level = Level(0), tile = {4, 5}})
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
		testing.expect(t, original[Stat_Name.Hitpoints] > MIN_STATS[.Hitpoints], "max hitpoints start at the floor, so the test proves little")

		character_set_equipped_item(pc, .Accessory, item)
		for v, s in pc.stats {
			want := MIN_STATS[Stat_Name(s)]
			testing.expectf(t, v == want, "%v equipped: %v is %v, want %v", item, Stat_Name(s), v, want)
		}

		character_set_equipped_item(pc, .Accessory, .None)
		testing.expectf(t, pc.stats == original, "%v unequipped: stats %v, want %v", item, pc.stats, original)
	}
}

// PC 0 with 100 max hitpoints, hurt to `hitpoints`, with no status and no
// evasion, so effects with 100 accuracy always land. Skills run as scripts
// that talk and pop up, so this needs headless_init; undo with headless_shutdown.
@(private = "file")
setup_target :: proc(hitpoints: int) -> ^Character {
	headless_init()
	init_new_game()
	pc := &playable_characters[0]
	remove_all_statuses(pc)
	pc.stats[Stat_Name.Hitpoints] = 100
	pc.stats[Stat_Name.Evasion] = 0
	pc.hitpoints = hitpoints
	return pc
}

@(test)
potion_heals_up_to_max_hitpoints :: proc(t: ^testing.T) {
	pc := setup_target(1); defer headless_shutdown()
	max_hp := 100
	pc.hitpoints = max_hp - 60
	testing.expect(t, run_skill(nil, {pc}, .Potion), "the potion never finished")
	testing.expect_value(t, pc.hitpoints, max_hp - 10)

	testing.expect(t, run_skill(nil, {pc}, .Potion), "the potion never finished")
	testing.expect_value(t, pc.hitpoints, max_hp)
}

@(test)
antidote_cures_poison :: proc(t: ^testing.T) {
	pc := setup_target(10); defer headless_shutdown()
	add_status(pc, .Poison)
	testing.expect(t, run_skill(nil, {pc}, .Antidote), "the antidote never finished")
	testing.expect(t, !has_status(pc^, .Poison), "still poisoned")
}

@(test)
poisonous_mushroom_heals_and_poisons :: proc(t: ^testing.T) {
	pc := setup_target(10); defer headless_shutdown()
	testing.expect(t, run_skill(nil, {pc}, .Poisonous_Mushroom), "the mushroom never finished")
	testing.expect(t, has_status(pc^, .Poison), "not poisoned")
	testing.expect_value(t, pc.hitpoints, 10 + 20)
}

@(test)
level_up_adds_a_level :: proc(t: ^testing.T) {
	pc := setup_target(10); defer headless_shutdown()
	level := pc.level
	testing.expect(t, run_skill(nil, {pc}, .Level_Up), "the level up never finished")
	testing.expect_value(t, pc.level, level + 1)
}

@(test)
suicide_downs_the_target :: proc(t: ^testing.T) {
	pc := setup_target(10); defer headless_shutdown()
	testing.expect(t, run_skill(nil, {pc}, .Suicide), "the suicide never finished")
	testing.expect_value(t, pc.hitpoints, 0)
}

// The Rat encounter, with PC 0 alone in the party.
@(private = "file")
setup_rat_battle :: proc() -> (baddy, player: ^Character) {
	headless_init() // spawns entities and runs skill scripts; undo with headless_shutdown
	init_new_game()
	game_data.party_membership = {true, false, false, false, false, false}
	encounter_init(.Rat, nil, nil, nil) // start_encounter fades the screen, so it must run in a script
	// The start proc has its moment before any skill play; skip it, or the first
	// update would spawn it and unpause the battle mid-play (encounter_init pauses it).
	battle.start_proc_run = true
	baddy, player = battle.combatants[battle.baddies[0]], battle.combatants[battle.players[0]]
	player.stats[Stat_Name.Evasion] = 0
	return
}

@(test)
pcs_keep_damage_and_status_after_battle :: proc(t: ^testing.T) {
	_, player := setup_rat_battle(); defer headless_shutdown()
	testing.expect(t, player == &playable_characters[0], "the player isn't PC 0")
	max_hp := playable_characters[0].hitpoints

	take_damage(player, 10)
	add_status(player, .Poison)
	battle_deactivate() // frees the baddy

	testing.expect_value(t, playable_characters[0].hitpoints, max_hp - 10)
	testing.expect(t, has_status(playable_characters[0], .Poison), "poison didn't stay")
}

@(test)
skill_plays_stagger_delays_turn_charge :: proc(t: ^testing.T) {
	baddy, player := setup_rat_battle(); defer headless_shutdown(); defer battle_deactivate()

	// stagger should delay the turn charge when the target isn't winding up
	player.charge = new_charge(max = 100, value = 100)
	player.windup = false

	battle.skill_play = {actor_idx = battle.baddies[0], targets = Target_One_Player{0}, skill_name = .Debug_Stagger}
	testing.expect(t, run_script(spawn(process_skill_play)), "the skill play never finished")
	testing.expect_value(t, player.charge.value, 100)
	testing.expect_value(t, player.charge.delay, 90) // Debug Stagger staggers 90
	testing.expect(t, !baddy.windup, "the actor is still winding up")
}

@(test)
skill_plays_stagger_delays_windup_charge :: proc(t: ^testing.T) {
	baddy, player := setup_rat_battle(); defer headless_shutdown(); defer battle_deactivate()

	// stagger should delay the skill play's charge when the target is winding up
	player.charge = new_charge(max = 100, value = 100)
	player.windup = true
	append(&battle.skill_plays, Battle_Skill_Play{actor_idx = battle.players[0], targets = Target_One_Baddy{0}, skill_name = .Slash, charge = new_charge(max = 100, value = 50)})

	battle.skill_play = {actor_idx = battle.baddies[0], targets = Target_One_Player{0}, skill_name = .Debug_Stagger}
	testing.expect(t, run_script(spawn(process_skill_play)), "the skill play never finished")
	testing.expect_value(t, player.charge, new_charge(max = 100, value = 100)) // the turn charge is untouched
	testing.expect_value(t, battle.skill_plays[0].charge.value, 50)
	testing.expect_value(t, battle.skill_plays[0].charge.delay, 50) // 90 capped at the charge's value
	testing.expect(t, !baddy.windup, "the actor is still winding up")
}

@(test)
item_counts_stay_between_0_and_max :: proc(t: ^testing.T) {
	init_new_game(); defer destroy()
	game_data.inventory[Item_Name.Potion] = 0
	add_item(.Potion, MAX_ITEM_COUNT + 1)
	testing.expect_value(t, game_data.inventory[Item_Name.Potion], MAX_ITEM_COUNT)
	game_data.inventory[Item_Name.Potion] = 2
	remove_item(.Potion, 5)
	testing.expect_value(t, game_data.inventory[Item_Name.Potion], 0)
}
