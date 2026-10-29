package game

import "core:slice"

Price :: Maybe(Money)

Item :: struct {
	name:        string,
	data:        Item_Variant,
	description: string,
	price:       Price,
}

Item_Variant :: union {
	Consumable,
	Equippable,
}

Consumable :: Skill_Name

Equippable :: struct {
	stats_add: Stats,
	stats_mul: Stats,
	slot:      Equipment_Slot,
}

NUM_ITEMS :: len(Item_Name) - 1

is_world_consumable :: proc(item_name: Item_Name) -> bool {
	if skill_name, is_consumable := items[item_name].data.(Consumable); is_consumable {
		return is_world_skill(skill_name)
	}
	return false
}

is_equippable_enum :: proc(item_name: Item_Name) -> bool {
	#partial switch data in items[item_name].data {
	case Equippable:
		return true
	}
	return false
}

is_equippable_int :: proc(item_idx: int) -> bool {
	return is_equippable_enum(Item_Name(item_idx))
}

is_equippable :: proc {
	is_equippable_enum,
	is_equippable_int,
}

filter_equippables :: proc(item_names: []Item_Name, allocator := context.allocator) -> []Item_Name {
	return slice.filter(item_names, is_equippable, allocator)
}

item_price :: proc(item_name: Item_Name) -> Price {
	return items[item_name].price
}

is_priceless :: proc(item_name: Item_Name) -> bool {
	return items[item_name].price == nil
}

can_sell :: proc(item_name: Item_Name) -> bool {
	return !is_priceless(item_name)
}
