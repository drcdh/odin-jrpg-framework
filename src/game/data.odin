package game

import "core:encoding/json"
import "core:encoding/uuid"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:time"

SAVE_DIR :: "saves"

Bool_Datum :: enum {
	Introduction,
	Met_Dude,
}

Int_Datum :: enum {
  Drink_Choice,
	Two_Quest,
	Demo_Quest,
}

Int_Data_Type :: i32

Money :: u32
MONEY_MAX :: 999999 //u32(0xffffffff)

Game_Data :: struct {
	bool_data:        [len(Bool_Datum)]bool,
	chest_data:       [len(Chest_Datum)]bool,
	int_data:         [len(Int_Datum)]Int_Data_Type,
	party_membership: [NUM_PC]bool,
	// boat_coord:       [2]i32, // Tile
	inventory:        [NUM_ITEMS]u8,
	money:            Money,
	steps:            u32,
	time:             u32,
}

Character_Save_Data :: struct {
	equipment:   Equipment,
	exp_to_next: Maybe(int),
	hitpoints:   int,
	level:       int,
	name:        string,
	status:      Status,
}

Party_Save_Data :: [NUM_PC]Character_Save_Data

Save_Data :: struct {
	game_data:      Game_Data,
	party_data: Party_Save_Data,
	save_point:     Save_Point,
	// time_loaded:      i64,
	time_saved:     i64,
}

Save_Point :: struct {
	level: Level,
	tile:  [2]i32, // Tile
}

game_data: Game_Data

// Frees everything the rules package allocated: the PCs, the inventory
// orders and the save-file metadata.
destroy :: proc() {
	delete_pcs()
	delete_inventory_order()
	metadata_unload()
}

init_new_game :: proc() {
	game_data = Game_Data{}
	// game_data.boat_coord = OVERWORLD_DEMO_BOAT_SPAWN
	game_data.party_membership = {true, false, false, false, false, false}
	for item_name in Item_Name {
		if item_name != .None {
			game_data.inventory[item_name] = 1
		}
	}
	game_data.money = Money(MONEY_MAX / 8)
	game_data.time = 0
	set_inventory_order()
	init_pcs()
	init_levels := [6]int{1, 1, 1, 1, 1, 1}
	for l, pc_idx in init_levels {
		set_level(&playable_characters[pc_idx], l)
		set_leveled_stats(&playable_characters[pc_idx])
	}
	set_all_skills()
	heal_party()
}

encode_party_data :: proc() -> (d: Party_Save_Data) {
	for pc, pc_idx in playable_characters {
		d[pc_idx].equipment = pc.equipment
		d[pc_idx].exp_to_next = pc.exp_to_next
		d[pc_idx].hitpoints = pc.hitpoints
		d[pc_idx].level = pc.level
		d[pc_idx].name = pc.name
		d[pc_idx].status = pc.status
	}
	return
}

save_game_now :: proc(filename: Maybe(string) = nil) -> bool {
	save_point := Save_Point{game.world.levels.current, entity_tile(player())}
	time_saved := time.to_unix_nanoseconds(time.now())
	return save_game(save_point, time_saved, filename)
}

save_game :: proc(save_point: Save_Point, time_saved: i64, filename: Maybe(string) = nil) -> bool {
	info := Save_Data{party_data = encode_party_data(), game_data = game_data, save_point = save_point, time_saved = time_saved}
	json_data, err := json.marshal(info, {pretty = true, use_enum_names = true}, context.temp_allocator)
	if err != nil {
		log.errorf("Unable to marshal JSON: %v", err)
		return false
	}

	if !os.exists(SAVE_DIR) {
		if mkerr := os.make_directory(SAVE_DIR); mkerr != nil {
			log.errorf("Unable to create directory '%s': %v", SAVE_DIR, mkerr)
			return false
		}
	}

	name, named := filename.?
	if !named do name = fmt.tprintf("odinjrpg_%s.json", uuid.to_string_allocated(uuid.generate_v7(), context.temp_allocator))
	filepath := fmt.tprintf("%s/%s", SAVE_DIR, name)
	if os.exists(filepath) do log.infof("Overwriting file %s", filepath)

	if werr := os.write_entire_file(filepath, json_data); werr != nil {
		log.errorf("Unable to write save game file: %v", werr)
		return false
	}

	log.infof("Saved game to %s", filepath)
	return true
}

// Reads SAVE_DIR/`filename`. The result is in the temp allocator.
read_saved_game_data :: proc(filename: string) -> (save_data: Save_Data, ok: bool) {
	filepath := strings.concatenate({SAVE_DIR, "/", filename}, context.temp_allocator)
	json_data, err := os.read_entire_file(filepath, context.temp_allocator)
	if err != nil {
		log.errorf("Failed to read the file '%s': %v", filepath, err)
		return
	}

	if unmarshal_err := json.unmarshal(json_data, &save_data, allocator = context.temp_allocator); unmarshal_err != nil {
		log.errorf("Failed to unmarshal save game data in '%s': %v", filepath, unmarshal_err)
		return
	}

	return save_data, true
}

load_saved_game :: proc(save_data: Save_Data) {
	game_data = save_data.game_data
	set_inventory_order()
	party_unequip_all(to_inventory = false)
	init_pcs()

	for csd, pc_idx in save_data.party_data {
		pc := &playable_characters[pc_idx]
		pc.status = csd.status
		for slot in Equipment_Slot {
			character_set_equipped_item(pc, slot, csd.equipment[slot], false, false)
		}
		set_level(pc, csd.level)
		pc.exp_to_next = csd.exp_to_next
		pc.hitpoints = csd.hitpoints
		delete(pc.name)
		pc.name = strings.clone(csd.name)
	}
	set_all_skills()
}

// Reads SAVE_DIR/`filename` into game_data and returns where the player was.
// Entering that level is the game package's job (game.load_game). Returns false
// (and logs why) if it couldn't.
load_game :: proc(filename: string) -> (save_point: Save_Point, ok: bool) {
	save_point = load_game(filename) or_return
	start_level(save_point.level, at = save_point.tile, face = .Down)
	log.infof("Loaded game from %s/%s", SAVE_DIR, filename)
	save_data := read_saved_game_data(filename) or_return
	load_saved_game(save_data)
	return save_data.save_point, true
}

get_game_data_bool :: proc(d: Bool_Datum) -> bool {
	return game_data.bool_data[d]
}

get_game_data_chest :: proc(d: Chest_Datum) -> bool {
	return game_data.chest_data[d]
}

get_game_data_int :: proc(d: Int_Datum) -> i32 {
	return game_data.int_data[d]
}

get_game_data :: proc {
	get_game_data_bool,
	get_game_data_chest,
	get_game_data_int,
}

game_bool_equals :: proc(d: Bool_Datum, v: bool) -> bool {
	return game_data.bool_data[d] == v
}

game_int_equals :: proc(d: Int_Datum, v: Int_Data_Type) -> bool {
	return game_data.int_data[d] == v
}

game_data_equals :: proc {
	game_bool_equals,
	game_int_equals,
}

set_game_data_bool :: proc(d: Bool_Datum, v: bool) {
	game_data.bool_data[d] = v
}

set_game_data_chest :: proc(d: Chest_Datum, v: bool) {
	game_data.chest_data[d] = v
}

set_game_data_int :: proc(d: Int_Datum, #any_int v: i32) {
	game_data.int_data[d] = v
}

set_game_data :: proc {
	set_game_data_bool,
	set_game_data_chest,
	set_game_data_int,
}

inc_money :: proc(v: Money) {
	prev := game_data.money
	game_data.money += v
	if game_data.money < prev {
		// overflowed
		game_data.money = MONEY_MAX
	}
	if game_data.money > MONEY_MAX {
		game_data.money = MONEY_MAX
	}
	log.infof("Money increased by %d from %d to %d", v, prev, game_data.money)
}

dec_money :: proc(v: Money) {
	prev := game_data.money
	if v >= game_data.money {
		game_data.money = 0
	} else {
		game_data.money -= v
	}
	log.infof("Money decreased by %d from %d to %d", v, prev, game_data.money)
}

have_money_Money :: proc(v: Money) -> bool {
	return game_data.money >= v
}

have_money_Price :: proc(v: Price) -> bool {
	switch v in v {
	case Money:
		return have_money_Money(Money(v))
	}
	return false
}

have_money :: proc {
	have_money_Money,
	have_money_Price,
}

get_sell_price :: proc(v: Money) -> Money {
	return Money(0.25 * f32(v))
}
