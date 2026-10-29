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

ZOOM :: 4
WINDOW_WIDTH :: ZOOM*game.WINDOW_WIDTH
WINDOW_HEIGHT :: ZOOM*game.WINDOW_HEIGHT

_ :: mem // only used in debug builds

Options :: struct {
	auto:			  bool `usage:"Autobattle mode, must be true if visual is false (default true)."`,
	seed: 		  u64  `usage:"Random seed (default 1959)."`,
	tscale: f32  `usage:"Modify factor for game time vs real time (default 1)."`,
	visual:     bool `usage:"Audiovisual mode (default false)."`,
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

	opt := Options{auto = true, seed = 1959, tscale = 1, visual = false}
	flags.parse_or_exit(&opt, os.args)
	log.infof("Setting random seed to %d", opt.seed)
	rand.reset(opt.seed)

	if opt.visual {
		rl.SetConfigFlags({.VSYNC_HINT})
		rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Autobattler")
		defer rl.CloseWindow()
		rl.SetTargetFPS(game.THROTTLED_FPS)
		rl.InitAudioDevice()
		defer rl.CloseAudioDevice() // after game.shutdown: it unloads sounds

		game.init(opt.tscale)
		defer game.shutdown() // before CloseWindow: it unloads textures

		game.init_new_game() // initializes party
		if opt.auto do game.set_autobattle(true)
		game.encounter_init(game.Encounter_Name.Rat)
		game.battle.paused = false

		for !rl.WindowShouldClose() {
			if result, ok := game.battle_result().?; ok {
				print_result(result)
				break
			}

			SRC :: rl.Rectangle{0, 0, game.WINDOW_WIDTH, -game.WINDOW_HEIGHT}
			DEST :: rl.Rectangle{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}

			game.input_update(rl.GetFrameTime())
			game.update(rl.GetFrameTime())
			game.draw()

			rl.BeginDrawing()
			rl.DrawTexturePro(game.texture.texture, SRC, DEST, {}, 0, rl.WHITE)
			rl.EndDrawing()

			free_all(context.temp_allocator)
		}

		game.scripts_shutdown()
		game.battle_deactivate()
		game.battle_destroy()
	} else if !opt.auto {
		fmt.println("auto must be true if visual is false")
	} else {
		game.init_new_game() // initializes party
		defer game.destroy()

		game.autobattle = true
		game.add_combatants_for_encounter(game.Encounter_Name.Rat)
		game.battle.active = true
		game.battle.paused = false

		defer game.battle_destroy()
		defer game.battle_deactivate()

		battle: for {
			game.battle_tick()
			if result, ok := game.check_win().?; ok {
				print_result(result)
				break battle
			}
		}
	}
}

print_result :: proc(result: game.Battle_Result) {
	switch result {
	case .Lose:
		fmt.println("BADDY TEAM WON")
	case .Win:
		fmt.println("PLAYER TEAM WON")
	}
	for pc_idx in 0 ..< game.party_size() {
		pc := game.get_party_member(pc_idx)
		fmt.printfln("%s: %d/%.0f HP %v", pc.name, pc.hitpoints, game.get_stat(pc^, .Hitpoints), pc.status)
	}
}
