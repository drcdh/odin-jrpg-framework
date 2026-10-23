package game

import "../rules"

// Chests: Box entities from the Tiled CHEST objects (process_tiled.py). Each
// one's Chest_Datum records whether it has been opened.

// A chest's trigger script: opens the box, gives `items` and says so. The box
// can't be opened again: its trigger is cleared and the datum is set, so the
// level spawns it opened from then on.
items_in_a_box :: proc(self: Entity_Id, datum: Chest_Datum, items: ..rules.Item_Name) {
	set_game_data(datum, true)
	clear_trigger(self)
	set_sprite_tag_of(self, .Opened)
	if len(items) == 0 {
		say("Ooh, nothing!")
		return
	}
	get_items(..items)
}
