#+private file
package content

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

	engine.spawn_entity(
		{
			name = "Button 1",
			sprite = engine.create_sprite_state(.Button),
			tile = GROVE_MAIN_PLAYER_SPAWN_INTRO + {1, 1},
			trigger = engine.new_trigger(proc(self: engine.Entity_Id) {
					engine.set_sprite_tag_of(self, .Down)
					engine.say("*Beep*")
					engine.pause(1)
					engine.set_sprite_tag_of(self, .Up)
				}),
		},
	)

	engine.spawn_entity(
		{
			name = "Button 2",
			sprite = engine.create_sprite_state(.Button),
			tile = GROVE_MAIN_PLAYER_SPAWN_INTRO + {2, 1},
			trigger = engine.new_trigger(proc(self: engine.Entity_Id) {
					engine.set_sprite_tag_of(self, .Down)
					engine.say("*Boop*", hurry = true, pause = .5)
					engine.pause(1)
					engine.set_sprite_tag_of(self, .Up)
				}),
		},
	)

	engine.spawn_entity(
		{
			name = "Lorem Ipsum sign",
			sprite = engine.create_sprite_state(.Sign),
			tile = GROVE_MAIN_SIGN,
			trigger = engine.new_trigger(proc(_: engine.Entity_Id) {
					engine.say(
						"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
					)
				}),
		},
	)

	engine.spawn_entity(
		{
			name    = "Jukebox",
			sprite  = engine.create_sprite_state(.Jukebox),
			tile    = GROVE_MAIN_JUKEBOX,
			trigger = engine.new_trigger(
				proc(_: engine.Entity_Id) {
					engine.set_busy_player()
					engine.say(
						"This may look like an ol'-timey jukebox, but it's actually a subtemporal meso-reconstructive bio-phasmatron! Use it, and almost instantaneously you'll feel like you've had a good long rest.",
					)
					ok: bool
					use: int
					if use, ok = engine.choose("Recover with the whatsit?", {"Use it!", "Nah, I'm good."}); !ok do return
					if use == 0 {
						pay: int
						if pay, ok = engine.choose("Sure. You still gotta put money in it, though. It's similar to a jukebox in that way.", {"Ugh, fine. $3", "What? No way."}); !ok do return
						if pay == 0 {
							if true || have_money(3) {
								dec_money(3)
								// music_fade_down()
								// fade screen out
								// heal_party()
								engine.pause(.75)
								// play_sound(.Warp)
								engine.pause(.75)
								// fade screen in
								// music_fade_up()
								engine.say("You feel great!")
								engine.pause(.5)
								engine.say("|but you're still hungry.")
							} else {
								engine.say("You can't afford it!")
							}
						}
					}
				},
			),
		},
	)

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
