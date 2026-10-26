package game

import "../rules"

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
		dude := spawn_entity({name = "Dude", tile = DUDE_PATH[0], facing = .Right, sprite = walker_sprite(.Dude)})
		spawn_entity({
			name   = "Fella",
			tile   = FELLA_PATH[0],
			facing = .Up,
			sprite = walker_sprite(.Man_Ps, PC_PALETTES[0][:]),
		})
		camera_follow(dude)
		set_curtain(1)
		spawn(intro_cutscene, name = "intro")
		return
	}

	monster_fight_stage = 0 // reset level-quest

	spawn_entity({
		name = "Fella",
		facing = .Left,
		sprite = walker_sprite(.Man_Ps, PC_PALETTES[0][:]),
		tile = QUARRY_MAIN_FELLA,
		trigger = new_trigger(proc(self: Entity_Id) {
			if monster_fight_stage == 0 {
				say("Oh, hey, $player. You wanna fight a special monster?", "Fella")
				ok: bool
				choice: int
				if choice, ok = choose("You'll get a prize if you win (maybe)!", {"I'm game.", "Nah, I'm good."}); !ok do return
				if choice == 0 {
					if rules.playable_characters[0].level >= 2 {
						monster_fight_stage = 1
						walk_entity(self, {1, -1})
						say("Go hog wild, champ.")
					} else {
						say("Hmm, I appreciate your spunk, but you're way too whimpy. Come back after you've {leveled up}, so to speak.")
					}
				}
			} else if monster_fight_stage == 1 {
				say("Go get 'em, tiger.", "Fella")
			} else if monster_fight_stage == 2 {
				say("Good job! Your prize is on back-order. Sorry|", "Fella")
			} else if monster_fight_stage == 3 {
				say("Oof, ouch. Come back another time.", "Fella")
			}
		})
	})

	spawn_entity({
		name = "Baddy",
		sprite = walker_sprite(.Baddy_World),
		tile = QUARRY_MAIN_BADDY,
		trigger = new_trigger(proc(self: Entity_Id) {
			say("Oh, excuse me. Battles aren't re-implemented yet, so let's just pretend to fight.")
			ok: bool
			choice: int
			if choice, ok = choose("Be the winner?", {"Yeah.", "Naw."}); !ok do return
			if choice == 0 {
				monster_fight_stage = 2
			} else {
				monster_fight_stage = 3
			}
			destroy_entity(self)
		})
	})
}

@(private = "file")
intro_cutscene :: proc(_: Entity_Id) {
	dude, fella := find("Dude"), find("Fella")

	walkers := [2]Script_Id {
		spawn(proc(self: Entity_Id) { walk_route(self, DUDE_PATH, once = true) }, dude, "intro: Dude"),
		spawn(proc(self: Entity_Id) { walk_route(self, FELLA_PATH, once = true) }, fella, "intro: Fella"),
	}
	pause(.5)
	fade_screen(0, 1.5)

	say("Did you hear? Somebody new is coming to the Grove today.", "Dude")
	say("Somebody new? Nobody new has come to town in years.", "Fella")
	say("That's what I said! I'm going to go and say hi.", "Dude")

	for w in walkers do wait_script(w)

	spawn(proc(self: Entity_Id) {
		if !walk_to(self, FELLA_PATH[2] + {0, -2}) do return
		set_facing(self, .Down)
		set_facing(find("Dude"), .Up)
	}, fella, "Fella move up")

	say("That's cool. I'm going to take a nap.", "Fella")
	say("Weirdo. Anyway, tea time!", "Dude")

	camera_to_tile(DUDE_PATH[1])
	spawn(proc(self: Entity_Id) { if !walk_to(self, {0, 9}) do return }, dude, "Dude leave")
	say("Caio.", "Fella")

	spawn(proc(self: Entity_Id) {
		if !pause(1) do return
		set_sprite_tag_of(self, .Downed)
	}, fella, "Fella nap")

	camera_to_tile({13, 9}, 1, .Sine_In_Out) // keeps panning through the fade out
	pause(2.5)
	change_level(.Grove_Main, at = GROVE_MAIN_PLAYER_SPAWN_INTRO, fade = 1.5)
}
