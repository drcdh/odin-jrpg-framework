package rules

import "core:log"

equippables_order: [dynamic]Item_Name
inventory_order: [dynamic]Item_Name

set_inventory_order :: proc() {
	clear(&inventory_order)
	for n, i in game_data.inventory {
		if n > 0 {
			append(&inventory_order, Item_Name(i))
		}
	}
	clear(&equippables_order)
	for n, i in game_data.inventory {
		if n > 0 && is_equippable(i) {
			append(&equippables_order, Item_Name(i))
		}
	}
	append(&equippables_order, Item_Name.None)
}

delete_inventory_order :: proc() {
	delete(equippables_order)
	delete(inventory_order)
	equippables_order, inventory_order = nil, nil
}

MAX_ITEM_COUNT :: 99

// Adds up to MAX_ITEM_COUNT of an item; any more are lost.
add_item :: proc(item_name: Item_Name, n: u8 = 1) {
	have := &game_data.inventory[item_name]
	have^ = u8(min(int(have^) + int(n), MAX_ITEM_COUNT))
	set_inventory_order()
	log.infof("Got %d %s", n, item_name)
}

// Removes up to as many of an item as there are.
remove_item :: proc(item_name: Item_Name, n: u8 = 1) {
	have := &game_data.inventory[item_name]
	have^ -= min(n, have^)
	set_inventory_order()
	log.infof("Lost %d %s", n, item_name)
}
