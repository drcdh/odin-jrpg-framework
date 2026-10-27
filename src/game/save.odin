package game

import "core:log"
import "core:time"
import "../rules"

// Saves the game data with where the player stands, to SAVE_DIR/`filename`
// (or a new uniquely named file). Returns false (and logs why) if it couldn't.
save_game :: proc(filename: Maybe(string) = nil) -> bool {
	save_point := rules.Save_Point{game.world.levels.current, entity_tile(player())}
	return rules.save_game(save_point, time.to_unix_nanoseconds(time.now()), filename)
}

// Loads the game data from SAVE_DIR/`filename`, then enters the saved level
// with the player on the saved tile, facing down.
load_game :: proc(filename: string) -> bool {
	save_point := rules.load_game(filename) or_return
	start_level(save_point.level, at = save_point.tile, face = .Down)
	log.infof("Loaded game from %s/%s", rules.SAVE_DIR, filename)
	return true
}
