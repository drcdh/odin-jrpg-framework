package game

// import "core:encoding/json"
// import "core:encoding/uuid"
import "core:fmt"
// import "core:os"
// import "core:strings"
// import "core:time"

SAVE_DIR :: "saves"

Bool_Datum :: enum {
	Introduction,
	Met_Dude,
	Met_Woman,
}

Int_Datum :: enum {
  Drink_Choice,
}

Int_Data_Type :: i32

Money :: u32
MONEY_MAX :: 999999 //u32(0xffffffff)

Game_Data :: struct {
	bool_data:        [len(Bool_Datum)]bool,
	chest_data:       [len(Chest_Datum)]bool,
	int_data:         [len(Int_Datum)]Int_Data_Type,
	// party_membership: [NUM_PC]bool,
	boat_coord:       Tile_Coord,
	// inventory:        [NUM_ITEMS]u8,
	money:            Money,
	steps:            u32,
	time:             u32,
}

// Character_Save_Data :: struct {
// 	equipment:   Equipment,
// 	exp_to_next: Maybe(int),
// 	hitpoints:   int,
// 	level:       int,
// 	name:        string,
// 	status:      Status,
// }

Save_Data :: struct {
	// character_data: [NUM_PC]Character_Save_Data,
	game_data:      Game_Data,
	// save_point:     Save_Point,
	// time_loaded:      i64,
	time_saved:     i64,
}

game_data: Game_Data

init_new_game :: proc() {
	game_data = Game_Data{}
	// game_data.boat_coord = OVERWORLD_DEMO_BOAT_SPAWN
	// game_data.party_membership = {true, false, false, false, false, false}
	// for item_name in Item_Name {
	// 	if item_name != .None {
	// 		game_data.inventory[item_name] = 1
	// 	}
	// }
	// game_data.money = Money(MONEY_MAX / 8)
	// game_data.time = 0
	// set_inventory_order()
	// init_pcs()
	// init_levels := [6]int{1, 1, 1, 1, 1, 1}
	// for l, pc_idx in init_levels {
	// 	set_level(&playable_characters[pc_idx], l)
	// 	set_leveled_stats(&playable_characters[pc_idx])
	// }
	// set_all_skills()
	// heal_party()
	// reset_save_points()
}

// encode_character_data :: proc() -> (d: [NUM_PC]Character_Save_Data) {
// 	for pc, pc_idx in playable_characters {
// 		d[pc_idx].equipment = pc.equipment
// 		d[pc_idx].exp_to_next = pc.exp_to_next
// 		d[pc_idx].hitpoints = pc.hitpoints
// 		d[pc_idx].level = pc.level
// 		d[pc_idx].name = pc.name
// 		d[pc_idx].status = pc.status
// 	}
// 	return
// }

// save_game :: proc(filepath: Maybe(string) = nil) {
// 	t := time.now()
// 	time_saved := t._nsec
// 	save_point := Save_Point{current_level, get_world_entity(PLAYER_ID).tile}
// 	info := Save_Data{encode_character_data(), game_data, save_point, time_saved}
//
// 	json_data, err := json.marshal(info, {pretty = true, use_enum_names = true})
// 	if err != nil {
// 		fmt.eprintfln("Unable to marshal JSON: %v", err)
// 		quitting = true
// 		return
// 	}
// 	defer delete(json_data)
//
// 	if filepath != nil {
// 		fmt.printfln("Overwriting file %s/%s", SAVE_DIR, filepath)
// 	}
//
// 	filepath :=
// 		filepath == nil ? fmt.aprintf("%s/odinjrpg_%s.json", SAVE_DIR, uuid.to_string_allocated(uuid.generate_v7(), context.temp_allocator)) : fmt.aprintf("%s/%s", SAVE_DIR, filepath)
// 	defer delete(filepath)
//
// 	werr := os.write_entire_file(filepath, json_data)
// 	if werr != nil {
// 		fmt.eprintfln("Unable to write save game file: %v", werr)
// 		quitting = true
// 	}
//
// 	fmt.printfln("Saved game to %s", filepath)
// }

// read_saved_game_data :: proc(filename: string) -> (save_data: Save_Data) {
// 	filepath := strings.concatenate({"./", SAVE_DIR, "/", filename}, context.temp_allocator)
// 	json_data, err := os.read_entire_file(filepath, context.temp_allocator)
// 	if err != nil {
// 		fmt.eprintfln("Failed to read the file '%s': %v", filepath, err)
// 		os.exit(1)
// 	}
//
// 	unmarshal_err := json.unmarshal(json_data, &save_data, allocator = context.temp_allocator)
// 	if unmarshal_err != nil {
// 		fmt.eprintfln("Failed to unmarshal save game data: %v", unmarshal_err)
// 		os.exit(1)
// 	}
//
// 	return
// }

// load_saved_game :: proc(save_data: Save_Data) {
// 	game_data = save_data.game_data
// 	set_inventory_order()
// 	party_unequip_all(to_inventory = false)
// 	init_pcs()
//
// 	for csd, pc_idx in save_data.character_data {
// 		pc := &playable_characters[pc_idx]
// 		pc.status = csd.status
// 		for slot in Equipment_Slot {
// 			character_set_equipped_item(pc, slot, csd.equipment[slot], false, false)
// 		}
// 		set_level(pc, csd.level)
// 		pc.exp_to_next = csd.exp_to_next
// 		pc.hitpoints = csd.hitpoints
// 		pc.name = strings.clone(csd.name)
// 	}
// 	set_all_skills()
// }

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
	fmt.printfln("Money increased by %d from %d to %d", v, prev, game_data.money)
}

dec_money :: proc(v: Money) {
	prev := game_data.money
	if v >= game_data.money {
		game_data.money = 0
	} else {
		game_data.money -= v
	}
	fmt.printfln("Money decreased by %d from %d to %d", v, prev, game_data.money)
}

have_money_Money :: proc(v: Money) -> bool {
	return game_data.money >= v
}

// have_money_Price :: proc(v: Price) -> bool {
// 	switch v in v {
// 	case Money:
// 		return have_money_Money(Money(v))
// 	}
// 	return false
// }

have_money :: proc {
	have_money_Money,
	// have_money_Price,
}

get_sell_price :: proc(v: Money) -> Money {
	return Money(0.25 * f32(v))
}
