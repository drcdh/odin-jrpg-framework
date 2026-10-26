#+feature using-stmt
package autobattler

import "core:flags"
import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:os"

import "../rules"

Options :: struct {
	seed: u64 `usage:"Random seed (default 1959)."`,
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

	using rules

	opt := Options{seed = 1959}
	flags.parse_or_exit(&opt, os.args)

	log.infof("Setting random seed to %d", opt.seed)
	rand.reset(opt.seed)

	init_new_game() // initializes party
	defer destroy()

	autobattle = true
	start_encounter(.Rat)
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

	// The PCs keep what happened to them in battle.
	for pc_idx in 0 ..< party_size() {
		pc := get_party_member(pc_idx)
		fmt.printfln("%s: %d/%.0f HP %v", pc.name, pc.hitpoints, get_stat(pc^, .Hitpoints), pc.status)
	}
}
