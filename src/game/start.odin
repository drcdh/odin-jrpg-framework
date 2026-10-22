package game

GAME_TITLE :: "Odin JRPG"

// Called by main after init.
start_game :: proc() {
	// TODO: enter the start menu
	new_game()
}

new_game :: proc() {
	// Eventually, this procedure should be called from the start menu when starting a new game
	init_new_game()
	start_level(.Grove_Main, at = GROVE_MAIN_PLAYER_SPAWN_INTRO)
}
