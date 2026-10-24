package game

// The opening cutscene, played in Quarry until it has a level of its own: no
// player, just Dude walking into the quarry's walled yard through the gap in
// its west wall and a stranger crossing the yard, meeting in the middle while
// they talk. Then a pause, a slow fade, and
// Grove starts the game proper.

// Starts the cutscene. Called by new_game. The NPCs spawn here, since sprites
// load on the main thread; the script finds them by name.
start_intro :: proc() {
	start_level(.Quarry_Main, with_player = false)
	dude := spawn_entity({name = "Dude", tile = DUDE_PATH[0], facing = .Right, sprite = walker_sprite(.Dude)})
	spawn_entity({
		name   = "Stranger",
		tile   = STRANGER_PATH[0],
		facing = .Up,
		sprite = walker_sprite(.Man_Ps, PC_PALETTES[0][:]),
	})
	camera_follow(dude)
	set_curtain(1) // opens dark; the script fades in once they're walking
	spawn(intro_cutscene, name = "intro")
}

@(private = "file")
INTRO_STEP :: 0.5 // seconds per tile
@(private = "file")
INTRO_DARK :: 0.5 // seconds of black before the fade in starts
@(private = "file")
INTRO_FADE :: 1.5

// The yard is tiles 7..12 square; its west wall has a gap at (6, 9).
@(private = "file", rodata)
DUDE_PATH := []Tile{{2, 9}, {9, 9}}
@(private = "file", rodata)
STRANGER_PATH := []Tile{{12, 12}, {12, 9}, {10, 9}}

@(private = "file")
intro_cutscene :: proc(_: Entity_Id) {
	dude, stranger := find("Dude"), find("Stranger")

	walkers := [2]Script_Id {
		spawn(proc(self: Entity_Id) { walk_route(self, DUDE_PATH, INTRO_STEP, once = true) }, dude, "intro: Dude"),
		spawn(proc(self: Entity_Id) { walk_route(self, STRANGER_PATH, INTRO_STEP, once = true) }, stranger, "intro: Stranger"),
	}
	pause(INTRO_DARK)
	fade_screen(0, INTRO_FADE)

	say("Did you hear? Somebody new is coming to the Grove today.", "Dude")
	say("Somebody new? Nobody new has come to town in years.", "Stranger")
	say("That's what I said! I'm going to go and say hi.", "Dude")

	for w in walkers do wait_script(w)
	say("Be nice. And don't offer them any of your terrible coffee.", "Stranger")
	say("My coffee is excellent.", "Dude")

	pause(3)
	change_level(.Grove_Main, at = GROVE_MAIN_PLAYER_SPAWN_INTRO, fade = 1.5)
}
