package game

GAME_TITLE :: "Odin JRPG"

SKIP_INTRO :: #config(SKIP_INTRO, false)

// Called by main after init.
start_game :: proc() {
	// TODO: enter the start menu
	new_game()
}

// Resets the game data and starts Quarry without a player, which plays the
// opening cutscene; it then starts Grove (level_quarry_main.odin).
new_game :: proc() {
	// Eventually, this procedure should be called from the start menu when starting a new game
	init_new_game()
	when SKIP_INTRO {
		start_level(.Grove_Main, at = GROVE_MAIN_PLAYER_SPAWN_INTRO)
	} else {
		start_level(.Quarry_Main, with_player = false)
	}
}
