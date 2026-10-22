package main

import "core:log"
import "core:mem"
import rl "vendor:raylib"
import "engine"
import "content"

_ :: mem // only used in debug builds

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)
		defer {
			for _, entry in track.allocation_map {
				log.errorf("%v leaked %v bytes", entry.location, entry.size)
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(engine.WINDOW_WIDTH, engine.WINDOW_HEIGHT, content.GAME_TITLE)
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	engine.init()
	defer engine.shutdown() // before CloseWindow: it unloads textures
	content.setup()

	for !rl.WindowShouldClose() {
		engine.clock_advance(rl.GetFrameTime())
		engine.input_update(rl.GetFrameTime())
		engine.update()

		rl.BeginDrawing()
		rl.ClearBackground({30, 30, 40, 255})
		rl.BeginMode2D(engine.camera())
		engine.draw_map()
		engine.draw_world()
		engine.draw_debug_world()
		rl.EndMode2D()
		engine.draw_screen_effects()
		engine.draw_dialogue()
		engine.draw_world_menu()
		engine.draw_debug_hud()
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}
}
