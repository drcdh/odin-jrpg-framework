package content

import "../engine"

// Stand-ins for old-project code that the generated level files
// (process_tiled.py) call: chests, items, encounters and saves. They do
// nothing or return defaults, so the chests in the maps don't appear yet.
// Replace each as the real feature lands.

Id :: distinct int

PLAYER_ID :: Id(0)

new_id :: proc() -> Id { return {} }

// The old entity shape the generated chest and egress code fills in.
Entity :: struct {
	id:    Id,
	ghost: bool,
	tile:  engine.Tile,
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

create_sprite_state :: proc(name: Legacy_Sprite, tag: engine.Sprite_Tag = {}) -> engine.Sprite_State { return {} }

Item :: enum {
	Potion,
}

Monster :: enum {
	Rat,
}

items_in_a_box   :: proc(id: Id, d: Chest_Datum, items: ..Item) {}
monster_in_a_box :: proc(id: Id, d: Chest_Datum, m: Monster, items: ..Item) {}

try_spawn_from_save :: proc() -> (tile: engine.Tile, face: engine.Direction, ok: bool) { return }
