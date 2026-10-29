package game

import rl "vendor:raylib"

_ :: rl // only used in debug builds

PLAYER_SPEED :: 2 // the player walks at 2x: half its sprite's default_step_time per tile

// In debug builds, F4 saves to and F5 loads from SAVE_DIR/TEST_SAVE.
TEST_SAVE :: "test.json"

Player_Control :: struct {
	step:     Tween_Id, // the current step; while it runs, input is ignored
	stepping: bool,     // `step` hasn't been checked for an edge exit yet
}

// The player's turn, first thing in update: level changes, then walking (held
// arrows) and talking (ENTER) for the player entity. Doors fire on their own
// when a step finishes (step triggers); the map edge is checked here.
@(private)
player_update :: proc() {
	when ODIN_DEBUG do if rl.IsKeyPressed(.F1) do toggle_debug()
	if world_menu_active() do return // it reads its own input
	if level_transition_update() do return

	// Test keys, debug builds only; saving also goes through the world menu.
	when ODIN_DEBUG {
		if rl.IsKeyPressed(.F4) do save_game_now(TEST_SAVE)
		if rl.IsKeyPressed(.F5) {
			load_game(TEST_SAVE)
			return
		}
	}

	// The dialogue box reads its own input; the player waits.
	if dialogue_active() do return

	pc := &game.world.player_control
	p := player()
	if !entity_alive(p) do return
	if !tween_done(pc.step) do return
	if pc.stepping {
		pc.stepping = false
		do_party_step_effects() // counts the step, ticks poison, charges skills
		check_edge_exit()
		if level_transition_update() do return
	}

	// A script holds the player (set_busy_player): no walking or talking.
	if is_busy(p) do return

	if get_input(.MENU) {
		// Only at rest: a script may be moving the player without holding it.
		if e, _ := entity_get(p); e.pos == tile_center(e.tile) do world_menu_enter()
		return
	}

	if dir, held := held_direction(); held {
		// Facing is the direction the player last tried to move, even into a wall.
		set_facing(p, dir)
		to := entity_tile(p) + dir_vec(dir)
		if tile_free(to, p) {
			pc.step = tween_to_tile(p, to, entity_step_time(p))
			pc.stepping = true
		}
	} else if get_input(.ENTER) {
		interact(p)
	}
}

// First held direction in a fixed order.
@(private = "file")
held_direction :: proc() -> (Direction, bool) {
	if get_input(.UP, down = true, silent = true)    do return .Up, true
	if get_input(.DOWN, down = true, silent = true)  do return .Down, true
	if get_input(.LEFT, down = true, silent = true)  do return .Left, true
	if get_input(.RIGHT, down = true, silent = true) do return .Right, true
	return {}, false
}
