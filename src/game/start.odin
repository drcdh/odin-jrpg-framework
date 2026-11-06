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
		change_level(.Grove_Main, at = GROVE_MAIN_PLAYER_SPAWN_INTRO, fade = 1)
	} else {
		change_level(.Quarry_Main, fade = 1)
	}
}

game_over :: proc() {
	start_menu_enter()
	fade_screen(0, .5)
	// game.quitting = true
}
