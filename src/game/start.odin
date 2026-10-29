package game

GAME_TITLE :: "Odin JRPG"
SPLASH_TITLE :: "ODIN JRPG"

SKIP_INTRO :: #config(SKIP_INTRO, false)

// Called by main after init. Last thing called before draw/update loop
start_game :: proc() {
	game.running = true
	start_menu_enter()
}

new_game :: proc() {
	init_new_game()
	when SKIP_INTRO {
		start_level(.Grove_Main, at = GROVE_MAIN_PLAYER_SPAWN_INTRO)
	} else {
		start_level(.Quarry_Main, with_player = false)
	}
}
