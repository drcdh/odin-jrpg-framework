package engine

import "core:log"
import "core:time"
import "../game"

// Saves the game data with where the player stands, to SAVE_DIR/`filename`
// (or a new uniquely named file). Returns false (and logs why) if it couldn't.
save_game :: proc(filename: Maybe(string) = nil) -> bool {
	save_point := game.Save_Point{world.levels.current, entity_tile(player())}
	return game.save_game(save_point, time.to_unix_nanoseconds(time.now()), filename)
}

// Loads the game data from SAVE_DIR/`filename`, then enters the saved level
// with the player on the saved tile, facing down.
load_game :: proc(filename: string) -> bool {
	save_point := game.load_game(filename) or_return
	start_level(save_point.level, at = save_point.tile, face = .Down)
	log.infof("Loaded game from %s/%s", game.SAVE_DIR, filename)
	return true
}
