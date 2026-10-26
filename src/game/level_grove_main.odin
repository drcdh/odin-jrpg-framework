#+private file
package game


dude_pace: Script_Id

@(private)
init_grove_main :: proc() {
	play_music(.Town)

	DRINK_TEA :: 1
	DRINK_COFFEE_BLACK :: 2
	DRINK_COFFEE_CREAM :: 3

	met := get_game_data(Bool_Datum.Met_Dude)
	dude := spawn_entity(
	{
		name    = "dude",
		tile    = GROVE_MAIN_DUDE_SPAWN_MET if met else GROVE_MAIN_DUDE_SPAWN_NOT_MET,
		sprite  = walker_sprite(.Dude),
		// Faces the player and stops pacing while they talk.
		trigger = new_trigger(
			proc(self: Entity_Id) {
				DUDE :: "Dude"
				if !get_game_data(Bool_Datum.Met_Dude) {
					set_game_data(Bool_Datum.Met_Dude, true)
					// Switch to route 1. The new pacer waits until the talk ends (busy).
					script_cancel(dude_pace)
					dude_pace = spawn(pace_dude_route_1, self, "dude pace")
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
							say(
								"So that's a coffee with cream? Cool, I dunno where a coffee shop is, though. Sorry!",
							)
						} else {
							set_game_data(Int_Datum.Drink_Choice, DRINK_COFFEE_BLACK)
							say(
								"So that's a black coffee? Cool, I dunno where a coffee shop is, though. Sorry!",
							)
						}
					} else {
						set_game_data(Int_Datum.Drink_Choice, DRINK_TEA)
						say("Ooh, grassy!")
						say(
							"Y'know what? I actually have an extra cup of hot tea right here. How about that?",
						)
						get_items(.Tea)
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
			},
		),
	},
	)
	dude_pace = spawn(pace_dude_route_1 if met else pace_dude_route_0, dude, "dude pace")

	spawn_entity(
		{
			name = "Button 1",
			sprite = create_sprite_state(.Button),
			tile = GROVE_MAIN_BUTTON_1,
			trigger = new_trigger(proc(self: Entity_Id) {
					set_sprite_tag_of(self, .Down)
					say("*Beep*")
					pause(1)
					set_sprite_tag_of(self, .Up)
				}),
		},
	)

	spawn_entity(
		{
			name = "Button 2",
			sprite = create_sprite_state(.Button),
			tile = GROVE_MAIN_BUTTON_2,
			trigger = new_trigger(proc(self: Entity_Id) {
					set_sprite_tag_of(self, .Down)
					say("*Boop*", hurry = true, pause = .5)
					pause(1)
					set_sprite_tag_of(self, .Up)
				}),
		},
	)

	spawn_entity(
		{
			name = "Lorem Ipsum sign",
			sprite = create_sprite_state(.Sign),
			tile = GROVE_MAIN_SIGN,
			trigger = new_trigger(proc(_: Entity_Id) {
					say(
						"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
					)
				}),
		},
	)

	spawn_entity(
		{
			name    = "Jukebox",
			sprite  = create_sprite_state(.Jukebox),
			tile    = GROVE_MAIN_JUKEBOX,
			trigger = new_trigger(
				proc(_: Entity_Id) {
					set_busy_player()
					say(
						"This may look like an ol'-timey jukebox, but it's actually a subtemporal meso-reconstructive bio-phasmatron! Use it, and almost instantaneously you'll feel like you've had a good long rest.",
					)
					ok: bool
					use: int
					if use, ok = choose("Recover with the whatsit?", {"Use it!", "Nah, I'm good."}); !ok do return
					if use == 0 {
						pay: int
						if pay, ok = choose("Sure. You still gotta put money in it, though. It's similar to a jukebox in that way.", {"Ugh, fine. $3", "What? No way."}); !ok do return
						if pay == 0 {
							if true || have_money(3) {
								dec_money(3)
								music_fade_down()
								fade_screen(1, .5)
								pause(1.25)
								heal_party()
								play_sound(.Warp)
								pause(.75)
								fade_screen(0, .5)
								music_fade_up()
								pause(.5)
								say("You feel great!")
								say("|but you're still hungry.")
							} else {
								say("You can't afford it!")
							}
						}
					}
				},
			),
		},
	)

	if !get_game_data(Bool_Datum.Introduction) {
		spawn(proc(self: Entity_Id) {
			say("You're new in town|\nPress Z to start!")
			set_game_data(Bool_Datum.Introduction, true)
		})
	}
}

pace_dude_route_0 :: proc(self: Entity_Id) {pace_route(self, GROVE_MAIN_DUDE_ROUTE_0)}
pace_dude_route_1 :: proc(self: Entity_Id) {pace_route(self, GROVE_MAIN_DUDE_ROUTE_1)}

// Walks to the start of the route, then paces it forever. walk_route closes
// the loop, so a two-point route goes out and back.
pace_route :: proc(self: Entity_Id, route_idx: int) {
	STEP :: 0.4
	PAUSE :: 0.25
	route := map_route(route_idx)
	if !walk_to(self, route[0], STEP, PAUSE) do return
	for {
		pause(PAUSE) or_break
		walk_route(self, route, STEP, PAUSE) or_break
	}
}
