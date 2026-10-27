package game

import "core:log"
import rl "vendor:raylib"

// game state specific to world mode: walking around a map, interacting with NPCs, etc.
World :: struct {
	camera:          Camera,
	level_map:       Level_Map,
	levels:          Levels, // the current level and level changes
	player:          Entity_Id,
	player_control:  Player_Control,
}

world_init :: proc(allocator := context.allocator) {
	log.info("initializing world")
}

world_shutdown :: proc() {
	log.info("shutting down world")
	game.world = {}
}

// One simulation step, starting with the player's turn. Call after
// clock_advance and input_update.
update_world :: proc() {
	player_update()
	world_menu_update()
	camera_update()
}

draw_world :: proc() {
	rl.BeginMode2D(game.world.camera)
	draw_map()
	draw_entities()
	draw_debug_world()
	rl.EndMode2D()
	draw_debug_world_hud()
	draw_world_menu()
}

player     :: proc() -> Entity_Id { return game.world.player }
set_player :: proc(id: Entity_Id) { game.world.player = id }

toggle_debug :: proc() { debug_overlay = !debug_overlay }
