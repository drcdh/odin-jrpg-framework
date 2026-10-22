package content

import "../engine"

GAME_TITLE :: "Odin JRPG"

start_game :: proc() {
	// TODO: enter start menu
	new_game()
}

new_game :: proc() {
	// Eventually, this procedure should be called from the start menu when starting a new game
	init_new_game()
	engine.start_level(.Grove_Main, at = GROVE_MAIN_PLAYER_SPAWN_INTRO)
}
