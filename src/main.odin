package main

import "core:log"
import "core:mem"
import rl "vendor:raylib"
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

	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(game.WINDOW_WIDTH, game.WINDOW_HEIGHT, game.GAME_TITLE)
	defer rl.CloseWindow()
	rl.SetTargetFPS(game.THROTTLED_FPS)
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice() // after game.shutdown: it unloads sounds

	game.init()
	defer game.shutdown() // before CloseWindow: it unloads textures
	game.start_game()

	for !rl.WindowShouldClose() {
		game.update()

		rl.BeginDrawing()
		rl.ClearBackground({30, 30, 40, 255})
		game.draw()
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}
}
