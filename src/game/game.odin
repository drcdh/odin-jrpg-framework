package game

import rl "vendor:raylib"
import "../engine"

STEP_TIME :: 0.15 // seconds per tile

// The player's current step; while it runs, input is ignored.
player_step: engine.Tween_Id
stepping:    bool // player_step hasn't been checked for an edge exit yet

setup :: proc() {
	start_level(.Grove_Main, at = GROVE_MAIN_PLAYER_SPAWN_INTRO)
}

update :: proc() {
	if rl.IsKeyPressed(.F1) do engine.toggle_debug()
	if update_transition() do return

	// While a dialogue box is up, Z closes it and the player can't move or talk.
	if engine.dialogue_active() {
		if rl.IsKeyPressed(.Z) do engine.dialogue_dismiss()
		return
	}

	player := engine.player()
	if !engine.tween_done(player_step) do return
	if stepping {
		// Doors fired when the step finished (step triggers); the edge is ours.
		stepping = false
		check_edge_exit()
		if update_transition() do return
	}

	if dir, held := held_direction(); held {
		// Facing is the direction the player last tried to move, even into a wall.
		engine.set_facing(player, dir)
		to := engine.entity_tile(player) + engine.dir_vec(dir)
		if engine.tile_free(to, player) {
			player_step = engine.tween_to_tile(player, to, STEP_TIME)
			stepping = true
		}
	} else if rl.IsKeyPressed(.Z) {
		engine.interact(player)
	}
}

// First held direction in a fixed order.
held_direction :: proc() -> (engine.Direction, bool) {
	if rl.IsKeyDown(.UP)    || rl.IsKeyDown(.W) do return .Up, true
	if rl.IsKeyDown(.DOWN)  || rl.IsKeyDown(.S) do return .Down, true
	if rl.IsKeyDown(.LEFT)  || rl.IsKeyDown(.A) do return .Left, true
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) do return .Right, true
	return {}, false
}
