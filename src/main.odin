package main

import "core:log"
import "core:mem"
import rl "vendor:raylib"
import "engine"
import "game"

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
	rl.InitWindow(1280, 720, "arglebargle")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	engine.init()
	defer engine.shutdown() // before CloseWindow: it unloads textures
	game.setup()

	for !rl.WindowShouldClose() {
		engine.clock_advance(rl.GetFrameTime())
		game.update()
		engine.update()

		rl.BeginDrawing()
		rl.ClearBackground({30, 30, 40, 255})
		rl.BeginMode2D(engine.camera())
		game.draw_floor()
		engine.draw_world()
		game.draw_overlay_world()
		engine.draw_debug_world()
		rl.EndMode2D()
		engine.draw_screen_effects()
		engine.draw_debug_hud()
		rl.DrawText("WASD / arrows: move    Z: talk    F1: debug overlay", 10, 695, 16, rl.GRAY)
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}
}
