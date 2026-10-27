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

Options :: struct {
	seed: u64 `usage:"Random seed (default 1959)."`,
	visual: bool `usage:"Audiovisual mode (default false)."`
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

	opt := Options{seed = 1959}
	flags.parse_or_exit(&opt, os.args)
	log.infof("Setting random seed to %d", opt.seed)
	rand.reset(opt.seed)

	if opt.visual {
		game.init(); defer game.shutdown()

		game.set_autobattle(true)
		game.start_encounter(rules.Encounter_Name.Rat)

		for !rl.WindowShouldClose() {
			game.clock_advance(rl.GetFrameTime())
			game.input_update(rl.GetFrameTime())
			game.update()

			rl.BeginDrawing()
			rl.ClearBackground({30, 30, 40, 255})
			game.draw_battle()
			game.draw_screen_effects()
			game.draw_dialogue()
			game.draw_debug_hud()
			game.debug_draw()
			rl.EndDrawing()

			free_all(context.temp_allocator)
		}
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
				switch result {
				case .Lose:
					fmt.println("BADDY TEAM WON")
				case .Win:
					fmt.println("PLAYER TEAM WON")
				}
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
