package engine

import hm "core:container/handle_map"
import "../game"

// The level-independent part of leaving a level. Everything a level added to
// the world goes: every entity, every tween, every script (cancelled ones
// finish on the next update), and the map. start_level then has the
// content build the next one.
clear_level :: proc() {
	it := hm.iterator_make(&world.entities)
	for _, h in hm.iterate(&it) do destroy_entity(h)
	entities_flush_destroyed()
	for h in world.script_order do script_cancel(h)
	// Remove rather than clear, so stale Tween_Ids stay invalid.
	tw := hm.iterator_make(&world.tweens)
	for _, h in hm.iterate(&tw) do hm.remove(&world.tweens, h)
	unload_map()
	world.level_map = {}
	world.player = {}
	world.camera_follow = {}
}

// --- Level changes ---

FADE_TIME :: 0.25 // seconds for each half of a level change

// Builds level `l` in the cleared world: its map, doors, the player (at `at`
// facing `face`, or by the level's entrance rules) and everything else. The
// game's content supplies it with set_level_enter.
Level_Enter :: #type proc(l: game.Level, at: Maybe(Tile), face: Direction)

Levels :: struct {
	current:    game.Level,
	prev:       game.Level, // the level left, with the player's tile and facing there
	prev_tile:  Tile,
	prev_face:  Direction,
	egress_idx: int, // the door (0 = the map edge) the player left `prev` by
	// Where stepping off the map edge goes; nil when the edges are closed.
	// Set by the generated tiled_init_* from the map's edge_level property.
	edge:       Maybe(game.Level),
	pending:    Maybe(game.Level), // the level being faded to
	transition: Tween_Id,          // the curtain tween of the current fade
	enter:      Level_Enter,
}

set_level_enter :: proc(enter: Level_Enter) {
	world.levels.enter = enter
}

current_level :: proc() -> game.Level {
	return world.levels.current
}

// Leaves the current level and enters `l`: clears the world, then the
// content's Level_Enter builds the new one, and the camera follows the player.
start_level :: proc(l: game.Level, at: Maybe(Tile) = nil, face := Direction.Down) {
	lv := &world.levels
	assert(lv.enter != nil, "start_level before set_level_enter")
	if p, ok := entity_get(player()); ok {
		lv.prev_face = p.facing
		lv.prev_tile = p.tile
	}
	lv.prev = lv.current
	lv.current = l
	lv.edge = nil
	clear_level()
	lv.enter(l, at, face)
	camera_follow(player())
}

restart_level :: proc() {
	start_level(world.levels.current)
}

// Leaving through a door or the map edge: fade out, enter `l`, fade in. The
// destination's entrance rules pick the spawn from the level left, the door
// index and the player's facing. Ignored while a level change is under way.
egress :: proc(l: game.Level, egress_idx: int) {
	lv := &world.levels
	if _, busy := lv.pending.?; busy do return
	lv.egress_idx = egress_idx
	lv.pending = l
	lv.transition = curtain_to(1, FADE_TIME)
}

// A warp pad. Same as egress until there are sounds to tell them apart.
warp_to_level :: proc(l: game.Level, egress_idx: int) {
	egress(l, egress_idx)
}

// Runs a level change. True while one is under way (including the fade back
// in), so the player can't act.
@(private)
level_transition_update :: proc() -> bool {
	lv := &world.levels
	if l, ok := lv.pending.?; ok {
		if !tween_done(lv.transition) do return true
		lv.pending = nil
		start_level(l)
		lv.transition = curtain_to(0, FADE_TIME)
		return true
	}
	return !tween_done(lv.transition)
}

// Called when the player finishes a step: stepping off the map edge leaves
// the level, if it has an edge exit.
@(private)
check_edge_exit :: proc() {
	l, ok := world.levels.edge.?
	if !ok || map_contains(entity_tile(player())) do return
	egress(l, 0)
}
