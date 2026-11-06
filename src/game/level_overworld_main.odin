package game

pebble_fought: bool

init_overworld_main :: proc() {
	play_music(.Overworld)

	spawn_entity({
		name = "suspicious_pebble",
		tile = OVERWORLD_MAIN_SUSPICIOUS_PEBBLE,
		trigger = new_trigger(proc(self: Entity_Id) {
			if pebble_fought do return
			say("There is a pebble here, and not just any pebble, but a suspicious pebble.")
			choice, _ := choose("Poke the suspicious pebble?", {"Yes.", "No."})
			if choice == 1 do return
			start_encounter(.Pebble)
			wait_battle()
			pause(.5)
			if battle_result() == .Win {
				say("The powerful pebble sits there, inert.")
			} else if battle_result() == .Lose {
				say("The powerful pebble sits there, inert and oddly satisfied looking.")
			}
			pebble_fought = true
		}),
	})
}
