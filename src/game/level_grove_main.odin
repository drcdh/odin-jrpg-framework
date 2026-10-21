#+private file
package game

import "../engine"

dude_pace: engine.Script_Id

@(private)
init_grove_main :: proc() {
	DRINK_TEA :: 1
	DRINK_COFFEE_BLACK :: 2
	DRINK_COFFEE_CREAM :: 3

	met := get_game_data(Bool_Datum.Met_Dude)
	dude := engine.spawn_entity(
	{
		name    = "dude",
		tile    = GROVE_MAIN_DUDE_SPAWN_MET if met else GROVE_MAIN_DUDE_SPAWN_NOT_MET,
		sprite  = character_sprite(),
		// Faces the player and stops pacing while they talk.
		trigger = engine.new_trigger(
			proc(self: engine.Entity_Id) {
				DUDE :: "Dude"
				if !get_game_data(Bool_Datum.Met_Dude) {
					set_game_data(Bool_Datum.Met_Dude, true)
					// Switch to route 1. The new pacer waits until the talk ends (busy).
					engine.script_cancel(dude_pace)
					dude_pace = engine.spawn(pace_dude_route_1, self, "dude pace")
					engine.say("Oh, hey! What's up, player?", DUDE)
					ok: bool
					drink: int
					if drink, ok = engine.choose("Coffee or tea?", {"Coffee", "Tea"}); !ok do return
					if drink == 0 {
						engine.say("Ooh, sludgy!")
						cream: int
						if cream, ok = engine.choose("With or without cream?", {"With", "Without"}); !ok do return
						if cream == 0 {
							set_game_data(Int_Datum.Drink_Choice, DRINK_COFFEE_CREAM)
							engine.say(
								"So that's a coffee with cream? Cool, I dunno where a coffee shop is, though. Sorry!",
							)
						} else {
							set_game_data(Int_Datum.Drink_Choice, DRINK_COFFEE_BLACK)
							engine.say(
								"So that's a black coffee? Cool, I dunno where a coffee shop is, though. Sorry!",
							)
						}
					} else {
						set_game_data(Int_Datum.Drink_Choice, DRINK_TEA)
						engine.say("Ooh, grassy!")
						engine.say(
							"Y'know what? I actually have an extra cup of hot tea right here. How about that?",
						)
					}
				} else {
					switch get_game_data(Int_Datum.Drink_Choice) {
					case DRINK_TEA:
						engine.say("How's that tea?")
					case DRINK_COFFEE_BLACK, DRINK_COFFEE_CREAM:
						engine.say("You ever find a coffee shop?")
					case:
						engine.say("Hi.")
					}
				}
			},
		),
	},
	)
	dude_pace = engine.spawn(pace_dude_route_1 if met else pace_dude_route_0, dude, "dude pace")

	if !get_game_data(Bool_Datum.Introduction) {
		engine.spawn(proc(self: engine.Entity_Id) {
			engine.say("You're new in town|\nPress Z to start!")
			set_game_data(Bool_Datum.Introduction, true)
		})
	}
}

pace_dude_route_0 :: proc(self: engine.Entity_Id) {pace_route(self, GROVE_MAIN_DUDE_ROUTE_0)}
pace_dude_route_1 :: proc(self: engine.Entity_Id) {pace_route(self, GROVE_MAIN_DUDE_ROUTE_1)}

// Walks to the start of the route, then paces it forever. walk_route closes
// the loop, so a two-point route goes out and back.
pace_route :: proc(self: engine.Entity_Id, route_idx: int) {
	STEP :: 0.4
	PAUSE :: 0.25
	route := engine.map_route(route_idx)
	if !engine.walk_entity(self, route[0] - engine.entity_tile(self), STEP, PAUSE) do return
	for {
		engine.pause(PAUSE) or_break
		engine.walk_route(self, route, STEP, PAUSE) or_break
	}
}
