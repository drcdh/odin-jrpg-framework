package game

// The yard is tiles 7..12 square; its west wall has a gap at (6, 9).
@(private = "file", rodata)
DUDE_PATH := []Tile{{2, 9}, {9, 9}}
@(private = "file", rodata)
FELLA_PATH := []Tile{{12, 12}, {12, 9}, {10, 9}}

@(private = "file")
monster_fight_stage: int

init_quarry_main :: proc() {
	play_music(.Town)

	if !get_game_data(Bool_Datum.Introduction) {
		dude := spawn_walker(name = "Dude", tile = DUDE_PATH[0], sprite = walker_sprite(.Dude))
		spawn_walker(
			name   = "Fella",
			tile   = FELLA_PATH[0],
			sprite = walker_sprite(.Man_Ps, PC_PALETTES[0][:]),
		)
		camera_follow(dude)
		set_curtain(1)
		spawn(intro_cutscene, name = "intro")
		return
	}

	monster_fight_stage = 0 // reset level-quest

	spawn_walker(
		name = "Fella",
		facing = .Left,
		sprite = walker_sprite(.Man_Ps, PC_PALETTES[0][:], tag=.Left),
		tile = QUARRY_MAIN_FELLA,
		talk = proc(self: Entity_Id) {
			set_control(false); defer set_control(true)
			name := entity_name(self)
			if monster_fight_stage == 0 {
				if game_data.party_membership[1] {
					say("Oh, hey, $one. Hi, $two. You two wanna fight a special monster?", name)
				} else {
					say("Oh, hey, $one. You wanna fight a special monster?", name)
				}
				ok: bool
				choice: int
				if choice, ok = choose("You'll get a prize if you win (maybe)!", {"I'm game.", "Nah, I'm good."}); !ok do return
				if choice == 0 {
					if playable_characters[0].level >= 2 {
						monster_fight_stage = 1
						walk_entity(self, {1, -1})
						set_facing(self, .Down)
						say("Go hog wild, champ.")
					} else {
						say("Hmm, I appreciate your spunk, but you're way too whimpy. Come back after you've {leveled up}, so to speak.")
					}
				}
			} else {
				set_facing_player(self); defer set_facing(self, .Down)
				if monster_fight_stage == 1 {
					say("Go get 'em, tiger.", name)
				} else if monster_fight_stage == 2 {
					say("Good job! Your prize is on back-order. Sorry|", name)
				} else if monster_fight_stage == 3 {
					say("Oof, ouch. Come back another time.", name)
				}
			}
		},
	)

	spawn_walker(
		name = "Baddy",
		sprite = walker_sprite(.Baddy_World),
		tile = QUARRY_MAIN_BADDY,
		talk = proc(self: Entity_Id) {
			set_facing_player(self); defer set_facing(self, .Down)
			name := entity_name(self)
			ok: bool
			choice: int
			if choice, ok = choose("Hello there! Isn't it a lovely day?", {"Fight!", "I choose peace."}, speaker = name); !ok do return
			if choice == 0 {
				start_encounter(.Mouse_Boss)
				wait_battle()
				pause(.5)
				if battle_result() == .Win {
					say("Well now the whole picnic is ruined.", speaker = name)
					monster_fight_stage = 2
				} else if battle_result() == .Lose {
					say("Looooooser.", speaker = name)
					monster_fight_stage = 3
				}
				fade_to(self, 0, 1)
				destroy_entity(self)
			}
		},
	)
}

@(private = "file")
intro_cutscene :: proc(_: Entity_Id) {
	dude, fella := find("Dude"), find("Fella")

	walkers := [2]Script_Id {
		spawn(proc(self: Entity_Id) { walk_route(self, DUDE_PATH) }, dude, "intro: Dude"),
		spawn(proc(self: Entity_Id) { walk_route(self, FELLA_PATH) }, fella, "intro: Fella"),
	}
	pause(.5)
	fade_screen(0, 1.5)

	say("Did you hear? We're in a demo of Daniel's JRPG engine.", dude)
	say("Wow! Is it written in Odin using just the core and Raylib packages?", fella)
	say("Darn tootin'. I'm going to go and say hi.", dude)

	for w in walkers do wait_script(w)

	spawn(proc(self: Entity_Id) {
		if !walk_to(self, FELLA_PATH[2] + {0, -2}) do return
		set_facing(self, .Down)
		set_facing(find("Dude"), .Up)
	}, fella, "Fella move up")

	say("That's cool. I'm going to take a nap.", fella)
	say("Weirdo. Anyway, tea time!", dude)

	camera_to_tile(DUDE_PATH[1])
	spawn(proc(self: Entity_Id) { if !walk_to(self, {0, 9}) do return }, dude, "Dude leave")
	say("Caio.", fella)

	spawn(proc(self: Entity_Id) {
		if !pause(1) do return
		set_sprite_tag_of(self, .Downed)
	}, fella, "Fella nap")

	camera_to_tile({13, 9}, 1, .Sine_In_Out) // keeps panning through the fade out
	pause(2.5)
	change_level(.Grove_Main, at = GROVE_MAIN_PLAYER_SPAWN_INTRO, fade = 1.5)
}
