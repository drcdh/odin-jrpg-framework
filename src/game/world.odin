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

world: World

world_init :: proc(allocator := context.allocator) {
	log.info("initializing world")
	world.camera.zoom = 1
}

world_shutdown :: proc() {
	log.info("shutting down world")
	world = {}
}

update_world :: proc() {
	player_update()
	update_darkness()
	update_overlay()
	world_menu_update()
}

draw_world :: proc() {
	rl.BeginMode2D(world.camera)
	draw_map()
	draw_entities()
	draw_debug_world()
	rl.EndMode2D()

	draw_darkness()
	draw_overlay()

	if world_menu_active() {
		// shade the world behind the menu
		rl.BeginBlendMode(.MULTIPLIED)
		rl.DrawRectangleV({}, {WINDOW_WIDTH, WINDOW_HEIGHT}, {120, 120, 165, 255})
		rl.EndBlendMode()
		draw_world_menu()
	} else {
		draw_debug_world_hud()
	}
}

player     :: proc() -> Entity_Id { return world.player }
set_player :: proc(id: Entity_Id) { world.player = id }

toggle_debug :: proc() { debug_overlay = !debug_overlay }
