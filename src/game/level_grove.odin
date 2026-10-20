package game

import "../engine"

init_grove_main :: proc() {
	player := engine.spawn_entity({
		name   = "player",
		tile   = GROVE_MAIN_PLAYER_SPAWN_INTRO,
		sprite = character_sprite(PLAYER_BODY, layer = 1),
	})
	engine.set_player(player)
}
