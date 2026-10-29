package game

import "core:fmt"

Equipment_Slot :: enum {
	Mainhand,
	Sidehand,
	Head,
	Body,
	Feet,
	Accessory,
}

NUM_EQUIPMENT_SLOTS :: len(Equipment_Slot)

Equipment :: [len(Equipment_Slot)]Item_Name

equipped_item_int :: proc(equipment: Equipment, slot: int) -> Item_Name {
	return equipment[slot]
}

equipped_item_slot :: proc(equipment: Equipment, slot: Equipment_Slot) -> Item_Name {
	return equipment[slot]
}

equipped_item :: proc {
	equipped_item_int,
	equipped_item_slot,
}

set_equipped_item :: proc(
	equipment: ^Equipment,
	slot: Equipment_Slot,
	item: Item_Name,
	from_inventory := true,
	to_inventory := true,
) {
	prev := equipment[slot]
	equipment[slot] = item
	if item != .None && from_inventory {
		remove_item(item, 1)
	}
	if prev != .None && to_inventory {
		add_item(prev, 1)
	}
	set_inventory_order()
}

unequip_all :: proc(equipment: ^Equipment, to_inventory := true) {
	for s in 0 ..< NUM_EQUIPMENT_SLOTS {
		set_equipped_item(equipment, Equipment_Slot(s), .None, false, to_inventory)
	}
	set_inventory_order()
}

equipment_string :: proc(equipment: Equipment, slot: Equipment_Slot) -> string {
	item := equipped_item(equipment, slot)
	item_name := items[item].name if item != .None else ""
	switch slot {
	case .Mainhand:
		return fmt.aprintf("Mainhand:  %s", item_name, allocator = context.temp_allocator)
	case .Sidehand:
		return fmt.aprintf("Sidehand:  %s", item_name, allocator = context.temp_allocator)
	case .Head:
		return fmt.aprintf("Head:      %s", item_name, allocator = context.temp_allocator)
	case .Body:
		return fmt.aprintf("Body:      %s", item_name, allocator = context.temp_allocator)
	case .Feet:
		return fmt.aprintf("Feet:      %s", item_name, allocator = context.temp_allocator)
	case .Accessory:
		return fmt.aprintf("Accessory: %s", item_name, allocator = context.temp_allocator)
	}
	return "bad_equipment_slot"
}

equipment_string_short :: proc(equipment: Equipment, slot: Equipment_Slot) -> cstring {
	item := equipped_item(equipment, slot)
	item_name := items[item].name if item != .None else ""
	switch slot {
	case .Mainhand:
		return fmt.ctprintf("M %s", item_name)
	case .Sidehand:
		return fmt.ctprintf("S %s", item_name)
	case .Head:
		return fmt.ctprintf("H %s", item_name)
	case .Body:
		return fmt.ctprintf("B %s", item_name)
	case .Feet:
		return fmt.ctprintf("F %s", item_name)
	case .Accessory:
		return fmt.ctprintf("A %s", item_name)
	}
	return "bad_equipment_slot"
}

fits_in_slot_equippable :: proc(item: Equippable, slot: Equipment_Slot) -> bool {
	return item.slot == slot
}

fits_in_slot_item :: proc(item: Item, slot: Equipment_Slot) -> bool {
	switch v in item.data {
	case Consumable:
		return false
	case Equippable:
		return fits_in_slot_equippable(v, slot)
	}
	return false
}

fits_in_slot_item_name :: proc(item: Item_Name, slot: Equipment_Slot) -> bool {
	if item == .None {return true}
	return fits_in_slot_item(items[item], slot)
}

fits_in_slot :: proc {
	fits_in_slot_equippable,
	fits_in_slot_item,
	fits_in_slot_item_name,
}

// FIXME: Odin doesn't have closures :-c
// filter_equipment_slot :: proc(
// 	item_names: []Item_Name,
// 	slot: Equipment_Slot,
// 	allocator := context.allocator,
// ) -> []Item_Name {
// 	return slice.filter(item_names, proc(item_name: Item_Name) -> bool {
// 			return fits_in_slot(item_name, slot)
// 		}, allocator)
// }

changed_equipment_enum_enum :: proc(
	equipment: Equipment,
	item_name: Item_Name,
	slot: Equipment_Slot,
) -> (
	changed: Equipment,
) {
	for s in Equipment_Slot {
		if s == slot && fits_in_slot(item_name, slot) {
			set_equipped_item(&changed, s, item_name, false, false)
		} else {
			set_equipped_item(&changed, s, equipment[s], false, false)
		}
	}
	return
}

changed_equipment_enum_int :: proc(equipment: Equipment, item: Item_Name, slot: int) -> Equipment {
	return changed_equipment_enum_enum(equipment, item, Equipment_Slot(slot))
}

changed_equipment_int_int :: proc(equipment: Equipment, item, slot: int) -> Equipment {
	return changed_equipment_enum_enum(equipment, Item_Name(item), Equipment_Slot(slot))
}

changed_equipment :: proc {
	changed_equipment_enum_enum,
	changed_equipment_enum_int,
	changed_equipment_int_int,
}

new_equipment :: proc(
	mainhand: Item_Name = .None,
	sidehand: Item_Name = .None,
	head: Item_Name = .None,
	body: Item_Name = .None,
	feet: Item_Name = .None,
	accessory: Item_Name = .None,
) -> Equipment {
	return {mainhand, sidehand, head, body, feet, accessory}
}
