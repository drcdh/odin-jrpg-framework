package game

import hm "core:container/handle_map"
import "core:log"
import "core:time"
import "../rules"

// The level-independent part of leaving a level. Everything a level added to
// the world goes: every entity, every tween, every script (cancelled ones
// finish on the next update), and the map. start_level then builds the
// next one with enter_level.
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

Levels :: struct {
	current:    rules.Level,
	prev:       rules.Level, // the level left, with the player's tile and facing there
	prev_tile:  Tile,
	prev_face:  Direction,
	egress_idx: int, // the door (0 = the map edge) the player left `prev` by
	// Where stepping off the map edge goes; nil when the edges are closed.
	// Set by the generated tiled_init_* from the map's edge_level property.
	edge:       Maybe(rules.Level),
	pending:    Maybe(rules.Level), // the level being faded to
	transition: Tween_Id,          // the curtain tween of the current fade
}

current_level :: proc() -> rules.Level {
	return world.levels.current
}

// Leaves the current level and enters `l`: clears the world, then the
// enter_level builds the new one, and the camera follows the player.
start_level :: proc(l: rules.Level, at: Maybe(Tile) = nil, face := Direction.Down) {
	lv := &world.levels
	if p, ok := entity_get(player()); ok {
		lv.prev_face = p.facing
		lv.prev_tile = p.tile
	}
	lv.prev = lv.current
	lv.current = l
	lv.edge = nil
	clear_level()
	enter_level(l, at, face)
	camera_follow(player())
}

restart_level :: proc() {
	start_level(world.levels.current)
}

// Leaving through a door or the map edge: fade out, enter `l`, fade in. The
// destination's entrance rules pick the spawn from the level left, the door
// index and the player's facing. Ignored while a level change is under way.
egress :: proc(l: rules.Level, egress_idx: int) {
	lv := &world.levels
	if _, busy := lv.pending.?; busy do return
	lv.egress_idx = egress_idx
	lv.pending = l
	lv.transition = curtain_to(1, FADE_TIME)
}

// A warp pad: egress with the warp sound.
warp_to_level :: proc(l: rules.Level, egress_idx: int) {
	play_sound(.Warp)
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

// Builds level `l` in the cleared world: the generated tiled_init_* sets the
// map and its doors, the player spawns (at `at` facing `face`, or by the
// level's entrance rules), the hand-written init_* adds the rest, and the
// generated render_* draws the map once.
@(private = "file")
enter_level :: proc(l: rules.Level, at: Maybe(Tile), face: Direction) {
	start := time.tick_now()
	tiled_init_level(l)
	spawn_player(l, at, face)
	init_level(l)
	render_level(l)
	log.infof("loaded level %v (%v tiles) in %v", l, world.level_map.size, time.tick_since(start))
}

@(private = "file")
spawn_player :: proc(l: rules.Level, at: Maybe(Tile), at_face: Direction) {
	tile, face := Tile{}, Direction.Down
	if t, ok := at.?; ok {
		tile, face = t, at_face
	} else if t2, f, found := player_spawn_level(l); found {
		tile, face = t2, f
	} else {
		lv := &world.levels
		tile = world.level_map.size / 2
		log.errorf("%v has no entrance for %v door %d facing %v; spawning the player at the map center %v",
			l, lv.prev, lv.egress_idx, lv.prev_face, tile)
	}
	player := spawn_entity({
		name   = "player",
		tile   = tile,
		facing = face,
		sprite = walker_sprite(.Player_World, layer = 1),
	})
	set_player(player)
}
