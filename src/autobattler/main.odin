#+feature using-stmt
package autobattler

import "core:flags"
import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:os"

import rl "vendor:raylib"

import "../game"
import "../rules"

_ :: mem // only used in debug builds

Options :: struct {
	auto: bool `usage:"Autobattle mode, must be true if visual is false (default true)."`,
	seed: u64 `usage:"Random seed (default 1959)."`,
	visual: bool `usage:"Audiovisual mode (default false)."`,
}

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	opt := Options{auto = true, seed = 1959}
	flags.parse_or_exit(&opt, os.args)
	log.infof("Setting random seed to %d", opt.seed)
	rand.reset(opt.seed)

	if opt.visual {
		rl.SetConfigFlags({.VSYNC_HINT})
		rl.InitWindow(game.WINDOW_WIDTH, game.WINDOW_HEIGHT, "Autobattler")
		defer rl.CloseWindow()
		rl.SetTargetFPS(game.THROTTLED_FPS)
		rl.InitAudioDevice()
		defer rl.CloseAudioDevice() // after game.shutdown: it unloads sounds

		game.init()
		defer game.shutdown() // before CloseWindow: it unloads textures

		rules.init_new_game() // initializes party
		if opt.auto do game.set_autobattle(true)
		game.start_encounter(rules.Encounter_Name.Rat)

		for !rl.WindowShouldClose() {
			if result, ok := game.battle_result().?; ok {
				print_result(result)
				break
			}

			game.clock_advance(rl.GetFrameTime())
			game.input_update(rl.GetFrameTime())
			game.update()

			rl.BeginDrawing()
			rl.ClearBackground({30, 30, 40, 255})
			rl.BeginMode2D(game.camera())
			game.draw_world()
			rl.EndMode2D()
			game.draw_battle()
			game.draw_screen_effects()
			game.draw_dialogue()
			game.draw_debug_hud()
			game.debug_draw()
			rl.EndDrawing()

			free_all(context.temp_allocator)
		}

		game.battle_deactivate()
		game.battle_destroy()
	} else if !opt.auto {
		fmt.println("auto must be true if visual is false")
	} else {
		using rules

		init_new_game() // initializes party
		defer destroy()

		autobattle = true
		start_encounter(rules.Encounter_Name.Rat)
		defer battle_destroy()

		battle: for {
			battle_tick()
			if result, ok := check_win().?; ok {
				print_result(result)
				break battle
			}
		}

		battle_cleanup()
	}

	// The PCs keep what happened to them in battle.
	for pc_idx in 0 ..< rules.party_size() {
		pc := rules.get_party_member(pc_idx)
		fmt.printfln("%s: %d/%.0f HP %v", pc.name, pc.hitpoints, rules.get_stat(pc^, .Hitpoints), pc.status)
	}
}

print_result :: proc(result: rules.Battle_Result) {
	switch result {
	case .Lose:
		fmt.println("BADDY TEAM WON")
	case .Win:
		fmt.println("PLAYER TEAM WON")
	}
}
