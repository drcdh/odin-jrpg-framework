package game

import hm "core:container/handle_map"
import "core:log"
import "core:time"

// The level-independent part of leaving a level. Everything a level added to
// the world goes: every entity, every tween, every script (cancelled ones
// finish on the next update), and the map. start_level then builds the
// next one with enter_level.
clear_level :: proc() {
	it := hm.iterator_make(&game.entities)
	for _, h in hm.iterate(&it) do destroy_entity(h)
	entities_flush_destroyed()
	for h in game.script_order do script_cancel(h)
	// Remove rather than clear, so stale Tween_Ids stay invalid.
	tw := hm.iterator_make(&game.tweens)
	for _, h in hm.iterate(&tw) do hm.remove(&game.tweens, h)
	unload_map()
	game.world.level_map = {}
	game.world.player = {}
	game.world.camera.focus = nil
	game.world.camera.pan = {}
}

// --- Level changes ---

FADE_TIME :: 0.25 // seconds for each half of a level change

Levels :: struct {
	current:      Level,
	prev:         Level, // the level left, with the player's tile and facing there
	prev_tile:    Tile,
	prev_face:    Direction,
	egress_idx:   int, // the door (0 = the map edge) the player left `prev` by
	// Where stepping off the map edge goes; nil when the edges are closed.
	// Set by the generated tiled_init_* from the map's edge_level property.
	edge:         Maybe(Level),
	pending:      Maybe(Level), // the level being faded to (change_level)
	pending_at:   Maybe(Tile),        // the player's spawn there; nil = the entrance rules
	pending_face: Direction,
	pending_fade: f32,                // seconds for each half of the change
	transition:   Tween_Id,           // the curtain tween of the current fade
}

current_level :: proc() -> Level {
	return game.world.levels.current
}

// Leaves the current level and enters `l`: clears the world, then the
// enter_level builds the new one, and the camera follows the player unless the
// level's init_* calls camera_follow. Without `with_player` (cutscenes) no
// player spawns, so nothing takes input and the camera follows nothing until
// init_* or a script calls camera_follow.
start_level :: proc(l: Level, at: Maybe(Tile) = nil, face := Direction.Down, with_player := true) {
	lv := &game.world.levels
	if p, ok := entity_get(player()); ok {
		lv.prev_face = p.facing
		lv.prev_tile = p.tile
	}
	lv.prev = lv.current
	lv.current = l
	lv.edge = nil
	clear_level()
	enter_level(l, at, face, with_player)
}

restart_level :: proc() {
	start_level(game.world.levels.current)
}

// A level change on the main thread, so scripts can ask for one (start_level
// would cancel the calling script): fade out over `fade` seconds, start `l`
// with the player at `at` facing `face`, fade back in. With no `at`, the
// level's entrance rules pick the spawn. Ignored while a change is under way.
change_level :: proc(l: Level, at: Maybe(Tile) = nil, face := Direction.Down, fade: f32 = FADE_TIME) {
	lv := &game.world.levels
	if _, busy := lv.pending.?; busy do return
	lv.pending = l
	lv.pending_at = at
	lv.pending_face = face
	lv.pending_fade = fade
	lv.transition = curtain_to(1, fade)
}

// Leaving through a door or the map edge: a level change whose spawn the
// destination's entrance rules pick from the level left, the door index and
// the player's facing.
egress :: proc(l: Level, egress_idx: int) {
	lv := &game.world.levels
	if _, busy := lv.pending.?; busy do return
	lv.egress_idx = egress_idx
	change_level(l)
}

// A warp pad: egress with the warp sound.
warp_to_level :: proc(l: Level, egress_idx: int) {
	play_sound(.Warp)
	egress(l, egress_idx)
}

// Runs a level change. True while one is under way (including the fade back
// in), so the player can't act.
@(private)
level_transition_update :: proc() -> bool {
	lv := &game.world.levels
	if l, ok := lv.pending.?; ok {
		if !tween_done(lv.transition) do return true
		lv.pending = nil
		start_level(l, lv.pending_at, lv.pending_face)
		lv.transition = curtain_to(0, lv.pending_fade)
		return true
	}
	return !tween_done(lv.transition)
}

// Called when the player finishes a step: stepping off the map edge leaves
// the level, if it has an edge exit.
@(private)
check_edge_exit :: proc() {
	l, ok := game.world.levels.edge.?
	if !ok || map_contains(entity_tile(player())) do return
	egress(l, 0)
}

// Builds level `l` in the cleared world: the generated tiled_init_* sets the
// map and its doors, the player spawns unless `with_player` is false (at `at`
// facing `face`, or by the level's entrance rules), the hand-written init_*
// adds the rest, and the
// generated render_* draws the map once.
@(private = "file")
enter_level :: proc(l: Level, at: Maybe(Tile), face: Direction, with_player: bool) {
	start := time.tick_now()
	tiled_init_level(l)
	if with_player do spawn_player(l, at, face)
	init_level(l)
	render_level(l)
	log.infof("loaded level %v (%v tiles) in %v", l, game.world.level_map.size, time.tick_since(start))
}

@(private = "file")
spawn_player :: proc(l: Level, at: Maybe(Tile), at_face: Direction) {
	tile, face := Tile{}, Direction.Down
	if t, ok := at.?; ok {
		tile, face = t, at_face
	} else if t2, f, found := player_spawn_level(l); found {
		tile, face = t2, f
	} else {
		lv := &game.world.levels
		tile = game.world.level_map.size / 2
		log.errorf("%v has no entrance for %v door %d facing %v; spawning the player at the map center %v",
			l, lv.prev, lv.egress_idx, lv.prev_face, tile)
	}
	sprite := walker_sprite(.Player_World, layer = 1)
	player := spawn_entity({
		name      = "player",
		tile      = tile,
		facing    = face,
		sprite    = sprite,
		step_time = default_step_time(sprite) / PLAYER_SPEED,
	})
	set_player(player)
	camera_follow(player) // before init_*, so a level can point the camera elsewhere
}
