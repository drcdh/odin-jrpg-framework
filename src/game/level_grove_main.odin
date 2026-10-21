package game

import "../engine"

choose :: engine.choose
say :: engine.say

init_grove_main :: proc() {
	DRINK_TEA :: 1
	DRINK_COFFEE_BLACK :: 2
	DRINK_COFFEE_CREAM :: 3

	dude := engine.spawn_entity(
	{
		name    = "dude",
		tile    = GROVE_MAIN_DUDE_SPAWN_NOT_MET,
		sprite  = character_sprite(),
		// Faces the player and stops pacing while they talk.
		trigger = engine.new_trigger(proc(self: engine.Entity_Id) {
			DUDE :: "Dude"
			if !get_game_data(Bool_Datum.Met_Dude) {
				set_game_data(Bool_Datum.Met_Dude, true)
				say("Oh, hey! What's up, player?", DUDE)
				ok: bool
				drink: int
				if drink, ok = choose("Coffee or tea?", {"Coffee", "Tea"}); !ok do return
				if drink == 0 {
					say("Ooh, sludgy!")
					cream: int
					if cream, ok = choose("With or without cream?", {"With", "Without"}); !ok do return
					if cream == 0 {
						set_game_data(Int_Datum.Drink_Choice, DRINK_COFFEE_CREAM)
						say("So that's a coffee with cream? Cool, I dunno where a coffee shop is, though. Sorry!")
					} else {
						set_game_data(Int_Datum.Drink_Choice, DRINK_COFFEE_BLACK)
						say("So that's a black coffee? Cool, I dunno where a coffee shop is, though. Sorry!")
					}
				} else {
					set_game_data(Int_Datum.Drink_Choice, DRINK_TEA)
					say("Ooh, grassy!")
					say("Y'know what? I actually have an extra cup of hot tea right here. How about that?")
				}
			} else {
				switch get_game_data(Int_Datum.Drink_Choice) {
				case DRINK_TEA:
					say("How's that tea?")
				case DRINK_COFFEE_BLACK, DRINK_COFFEE_CREAM:
					say("You ever find a coffee shop?")
				case:
					say("Hi.")
				}
			}
		}),
	},
	)
	engine.spawn(pace_dude_route_0, dude, "dude pace")

	if !get_game_data(Bool_Datum.Introduction) {
		engine.spawn(proc(self: engine.Entity_Id) {
			engine.say("You're new in town|\nPress Z to start!")
			set_game_data(Bool_Datum.Introduction, true)
		})
	}
}

// Walks to the start of dude_route_0, then paces it forever. The route is a
// two-point polyline, so walk_route goes out and back.
pace_dude_route_0 :: proc(self: engine.Entity_Id) {
	STEP :: 0.4
	PAUSE :: 0.25
	route := engine.map_route(GROVE_MAIN_DUDE_ROUTE_0)
	if !engine.walk_entity(self, route[0] - engine.entity_tile(self), STEP, PAUSE) do return
	for {
		engine.pause(PAUSE) or_break
		engine.walk_route(self, route, STEP, PAUSE) or_break
	}
}
