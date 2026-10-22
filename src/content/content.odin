package content

import "../engine"

// Hands the engine the level builder, then starts the game.
setup :: proc() {
	engine.set_level_enter(enter_level)
	// TODO: enter the start menu
	start_game() // eventually, this will only be called when starting a new game from the start menu
}
