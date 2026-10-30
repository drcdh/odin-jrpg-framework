package game

import hm "core:container/handle_map"
import "core:log"

Entity_Id :: distinct hm.Handle32

Entity :: struct {
	handle:  Entity_Id,
	name:    string,
	tile:    Tile,
	pos:     [2]f32,
	facing:  Direction,
	busy:    bool,      // other scripts than busy_by can't move or turn it; see set_busy
	busy_by: Script_Id, // the script that set busy; {} = the main thread
	ghost:   bool,      // neither blocks nor is blocked by other entities
	battle:  bool,      // a combatant or skill animation; drawn by draw_battle, not draw_world
	on_step: proc(self, by: Entity_Id), // runs on the main thread when another entity finishes a step onto this tile
	sprite:  Sprite_State,
	trigger: Trigger,
	// Seconds per tile when walking (walk verbs, player steps). It also sets
	// how fast a Moving sprite animates: one loop per tile. 0 on spawn means
	// the default, default_step_time.
	step_time: f32,
	light: f32,
}

DEFAULT_STEP_TIME :: 0.5 // seconds per tile for an entity without an animated sprite

// "1x" walking: one loop of the sprite's current row per tile at normal
// playback speed, or DEFAULT_STEP_TIME without an animated row.
default_step_time :: proc(s: Sprite_State) -> f32 {
	if l := animation_length(s); l > 0 do return l
	return DEFAULT_STEP_TIME
}

entity_step_time :: proc(id: Entity_Id) -> f32 {
	if e, ok := entity_get(id); ok do return e.step_time
	return DEFAULT_STEP_TIME
}

spawn_entity :: proc(e: Entity) -> Entity_Id {
	e := e
	e.pos = tile_center(e.tile)
	if e.step_time == 0 do e.step_time = default_step_time(e.sprite)
	h, err := hm.add(&game.entities, e)
	assert(err == nil, "out of memory spawning entity")
	return h
}

entity_get :: proc(id: Entity_Id) -> (^Entity, bool) #optional_ok {
	return hm.get(&game.entities, id)
}

entity_alive :: proc(id: Entity_Id) -> bool {
	return hm.is_valid(&game.entities, id)
}

find :: proc(name: string, loc := #caller_location) -> Entity_Id {
	it := hm.iterator_make(&game.entities)
	for e, h in hm.iterate(&it) {
		if e.name == name do return h
	}
	log.warnf("find: no entity named %q", name, location = loc)
	return {}
}

// True while `id` is busy (set_busy) with something other than the running
// script, which may then not move or turn it. Always false on the main thread.
entity_busy :: proc(id: Entity_Id) -> bool {
	return current_script != nil && entity_held(id, current_script.handle)
}

// Whether `id` is busy (set_busy) with anything, as the game sees it: the
// flag is set and its script, if any, is still running. The game checks this
// for the player (set_busy_player) to ignore movement and interact input.
is_busy :: proc(id: Entity_Id) -> bool {
	e, ok := entity_get(id)
	return ok && e.busy && (e.busy_by == {} || script_alive(e.busy_by))
}

// Whether script `by` is held off `id`. Busy lapses when its script ends.
@(private)
entity_held :: proc(id: Entity_Id, by: Script_Id) -> bool {
	e, ok := entity_get(id)
	if !ok || !e.busy || by == e.busy_by do return false
	return e.busy_by == {} || script_alive(e.busy_by)
}

entity_pos :: proc(id: Entity_Id) -> [2]f32 {
	if e, ok := entity_get(id); ok do return e.pos
	return {}
}

entity_tile :: proc(id: Entity_Id) -> Tile {
	if e, ok := entity_get(id); ok do return e.tile
	return {}
}

// Fires the step triggers of the other entities on `id`'s tile. Called when a
// tile move (tween_to_tile, so also walk_entity) finishes; not on spawn or set_tile.
entity_arrived :: proc(id: Entity_Id) {
	// In WRAP mode, an entity that walked off the edge comes back in on the
	// other side; the map repeats, so nothing visibly jumps.
	if world.level_map.mode == .WRAP && !map_contains(entity_tile(id)) {
		set_tile(id, wrap_tile(entity_tile(id)))
	}
	tile := entity_tile(id)
	triggers := make([dynamic]Entity_Id, context.temp_allocator)
	it := hm.iterator_make(&game.entities)
	for e, h in hm.iterate(&it) {
		if h != id && e.on_step != nil && e.tile == tile do append(&triggers, h)
	}
	for h in triggers {
		if e, ok := entity_get(h); ok do e.on_step(h, id)
	}
}

// Destruction is deferred to the end of update, so the entity stays valid for
// the rest of the frame. Its tweens and the scripts running on it are cancelled.
destroy_entity :: proc(id: Entity_Id) {
	if !entity_alive(id) do return
	for pending in game.pending_destroy do if pending == id do return
	append(&game.pending_destroy, id)
}

entities_flush_destroyed :: proc() {
	for id in game.pending_destroy {
		tweens_cancel_for_entity(id)
		scripts_cancel_for_entity(id)
		hm.remove(&game.entities, id)
	}
	clear(&game.pending_destroy)
}
