package game

GAME_TITLE :: "Odin JRPG"

// Called by main after init.
start_game :: proc() {
	// TODO: enter the start menu
	new_game()
}

// Resets the game data and plays the opening cutscene, which then starts
// Grove (level_cutscene_intro.odin).
new_game :: proc() {
	// Eventually, this procedure should be called from the start menu when starting a new game
	init_new_game()
	start_intro()
}
