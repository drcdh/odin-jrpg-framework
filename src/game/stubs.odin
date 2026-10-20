package game

import "../engine"

// Stand-ins for old-project code that the generated level files
// (process_tiled.py) call: chests, doors, items, encounters and saves. They
// do nothing or return defaults, so the map objects that use them (Grove's
// chests and warps) don't appear yet. Replace each as the real feature lands.

Id :: distinct int

PLAYER_ID :: Id(0)

new_id :: proc() -> Id { return {} }

// The old entity shape the generated chest and egress code fills in.
Entity :: struct {
	id:    Id,
	ghost: bool,
	tile:  Tile_Coord,
	n:     string,
	talk:  proc(id: Id),
	trap:  proc(id, c_id: Id),
	v:     engine.Sprite_State,
}

add_world_entity :: proc(e: Entity) {}

// Sprites the generated code names that this project doesn't have yet.
Legacy_Sprite :: enum {
	Box,
	Warp,
}

create_sprite_state :: proc(name: Legacy_Sprite, tag: Sprite_Tag = {}) -> engine.Sprite_State { return {} }

get_game_data :: proc(d: Chest_Datum) -> bool { return false }

Item :: enum {
	Potion,
}

Monster :: enum {
	Rat,
}

items_in_a_box   :: proc(id: Id, d: Chest_Datum, items: ..Item) {}
monster_in_a_box :: proc(id: Id, d: Chest_Datum, m: Monster, items: ..Item) {}

warp_to_level :: proc(l: Level, door_idx: int) {}
egress        :: proc(l: Level, door_idx: int) {}

try_spawn_from_save :: proc() -> (tile: Tile_Coord, face: Sprite_Tag, ok: bool) { return }
