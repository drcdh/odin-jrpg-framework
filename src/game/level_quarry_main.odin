package game

@(private = "file")
INTRO_DARK :: 0.5 // seconds of black before the fade in starts
@(private = "file")
INTRO_FADE :: 1.5
@(private = "file")
INTRO_PAN_TO :: Tile{13, 9} // where the camera drifts to as the scene fades out
@(private = "file")
INTRO_PAN_SPEED :: 1 // tiles per second

// The yard is tiles 7..12 square; its west wall has a gap at (6, 9).
@(private = "file", rodata)
DUDE_PATH := []Tile{{2, 9}, {9, 9}}
@(private = "file", rodata)
STRANGER_PATH := []Tile{{12, 12}, {12, 9}, {10, 9}}

// The map, its doors and the player come from the generated level code and
// enter_level. Until the Introduction flag is set (by Grove), entering Quarry
// plays the opening cutscene: new_game starts it without a player, the
// screen opens black and fades in once Dude and a stranger are walking, the
// camera follows Dude, and the cutscene ends by changing to Grove.
init_quarry_main :: proc() {
	play_music(.Town)

	if !get_game_data(Bool_Datum.Introduction) {
		dude := spawn_entity({name = "Dude", tile = DUDE_PATH[0], facing = .Right, sprite = walker_sprite(.Dude)})
		spawn_entity({
			name   = "Stranger",
			tile   = STRANGER_PATH[0],
			facing = .Up,
			sprite = walker_sprite(.Man_Ps, PC_PALETTES[0][:]),
		})
		camera_follow(dude)
		set_curtain(1)
		spawn(intro_cutscene, name = "intro")
	}
}

@(private = "file")
intro_cutscene :: proc(_: Entity_Id) {
	dude, stranger := find("Dude"), find("Stranger")

	walkers := [2]Script_Id {
		spawn(proc(self: Entity_Id) { walk_route(self, DUDE_PATH, once = true) }, dude, "intro: Dude"),
		spawn(proc(self: Entity_Id) { walk_route(self, STRANGER_PATH, once = true) }, stranger, "intro: Stranger"),
	}
	pause(INTRO_DARK)
	fade_screen(0, INTRO_FADE)

	say("Did you hear? Somebody new is coming to the Grove today.", "Dude")
	say("Somebody new? Nobody new has come to town in years.", "Stranger")
	say("That's what I said! I'm going to go and say hi.", "Dude")

	for w in walkers do wait_script(w)

	spawn(proc(self: Entity_Id) {
		if !walk_to(self, STRANGER_PATH[2] + {0, -2}) do return
		set_facing(self, .Down)
		set_facing(find("Dude"), .Up)
	}, stranger, "Stranger move up")

	say("That's cool. I'm going to take a nap.", "Stranger")
	say("Weirdo. Anyway, tea time!", "Dude")

	spawn(proc(self: Entity_Id) { if !walk_to(self, {0, 9}) do return }, dude, "Dude leave")
	say("Caio.", "Stranger")

	spawn(proc(self: Entity_Id) {
		if !pause(1) do return
		set_sprite_tag_of(self, .Downed)
	}, stranger, "Stranger nap")

	camera_to_tile(INTRO_PAN_TO, INTRO_PAN_SPEED, .Sine_In_Out) // keeps panning through the fade out
	pause(2.5)
	change_level(.Grove_Main, at = GROVE_MAIN_PLAYER_SPAWN_INTRO, fade = 1.5)
}
