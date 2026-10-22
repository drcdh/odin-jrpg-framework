package game

import rl "vendor:raylib"
import "../engine"

STEP_TIME :: 0.15 // seconds per tile

// F4 saves to and F5 loads from SAVE_DIR/TEST_SAVE (temporary).
TEST_SAVE :: "test.json"

// The player's current step; while it runs, input is ignored.
player_step: engine.Tween_Id
stepping:    bool // player_step hasn't been checked for an edge exit yet

setup :: proc() {
	// TODO: enter the start menu
	start_game() // eventually, this will only be called when starting a new game from the start menu
}

update :: proc() {
	if rl.IsKeyPressed(.F1) do engine.toggle_debug()
	if update_transition() do return

	// TODO: temporary; saving and loading will go through menus.
	if rl.IsKeyPressed(.F4) do save_game(TEST_SAVE)
	if rl.IsKeyPressed(.F5) {
		load_game(TEST_SAVE)
		return
	}

	// The dialogue box reads its own input; the player waits.
	if engine.dialogue_active() do return

	player := engine.player()
	if !engine.tween_done(player_step) do return
	if stepping {
		// Doors fired when the step finished (step triggers); the edge is ours.
		stepping = false
		check_edge_exit()
		if update_transition() do return
	}

	// A script holds the player (set_busy_player): no walking or talking.
	if engine.is_busy(player) do return

	if dir, held := held_direction(); held {
		// Facing is the direction the player last tried to move, even into a wall.
		engine.set_facing(player, dir)
		to := engine.entity_tile(player) + engine.dir_vec(dir)
		if engine.tile_free(to, player) {
			player_step = engine.tween_to_tile(player, to, STEP_TIME)
			stepping = true
		}
	} else if engine.get_input(.ENTER) {
		engine.interact(player)
	}
}

// First held direction in a fixed order.
held_direction :: proc() -> (engine.Direction, bool) {
	if engine.get_input(.UP, down = true, silent = true)    do return .Up, true
	if engine.get_input(.DOWN, down = true, silent = true)  do return .Down, true
	if engine.get_input(.LEFT, down = true, silent = true)  do return .Left, true
	if engine.get_input(.RIGHT, down = true, silent = true) do return .Right, true
	return {}, false
}
