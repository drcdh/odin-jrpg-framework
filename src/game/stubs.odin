package game

// Stand-ins for old-project code that the generated level files
// (process_tiled.py) call: chests, items, encounters and saves. They do
// nothing or return defaults, so the chests in the maps don't appear yet.
// Replace each as the real feature lands.

Legacy_Id :: distinct int

LEGACY_PLAYER_ID :: Legacy_Id(0)

legacy_id :: proc() -> Legacy_Id { return {} }

// The old entity shape the generated chest and egress code fills in.
Legacy_Entity :: struct {
	id:    Legacy_Id,
	ghost: bool,
	tile:  Tile,
	n:     string,
	talk:  proc(id: Legacy_Id),
	trap:  proc(id, c_id: Legacy_Id),
	v:     Sprite_State,
}

add_legacy_entity :: proc(e: Legacy_Entity) {}

// Sprites the generated code names that this project doesn't have yet.
Legacy_Sprite :: enum {
	Box,
	Warp,
}

legacy_sprite_state :: proc(name: Legacy_Sprite, tag: Sprite_Tag = {}) -> Sprite_State { return {} }

Item :: enum {
	Potion,
}

Monster :: enum {
	Rat,
}

items_in_a_box   :: proc(id: Legacy_Id, d: Chest_Datum, items: ..Item) {}
monster_in_a_box :: proc(id: Legacy_Id, d: Chest_Datum, m: Monster, items: ..Item) {}

try_spawn_from_save :: proc() -> (tile: Tile, face: Direction, ok: bool) { return }
