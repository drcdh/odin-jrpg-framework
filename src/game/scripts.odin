package game

import "core:log"
import "core:math/rand"
import rl "vendor:raylib"

import "../rules"

// Flash the player red, slide away, wait, then restore the player's tint.
glide_away :: proc(self: Entity_Id) {
	player := player()
	set_tint(player, rl.RED)
	move_entity(self, {4, 0}, 1.0, .Quadratic_In_Out)
	pause(2)
	set_tint(player, rl.WHITE)
	move_entity(self, {-4, 0}, 0.5, .Cubic_Out)
}

// Runs for the entity's whole life. Steps a tile, waits 0.25 s, steps again,
// including at the turnarounds. The bool results let it stop when cancelled.
patrol :: proc(self: Entity_Id) {
	STEP  :: 0.4
	PAUSE :: 0.25
	for {
		walk_entity(self, {5, 0}, STEP, PAUSE) or_break
		pause(PAUSE) or_break
		walk_entity(self, {-5, 0}, STEP, PAUSE) or_break
		pause(PAUSE) or_break
	}
}

// Corners of the route patroller's loop. Adjacent vertices (and the last and
// first) differ in only one dimension.
PATROL_ROUTE := [?]Tile{{15, 1}, {18, 1}, {18, 4}, {17, 4}, {17, 7}, {15, 7}}

// Loops the route forever with the same rhythm as `patrol`: a tile every
// 0.4 s with a 0.25 s pause between moves, corners included.
patrol_route :: proc(self: Entity_Id) {
	STEP  :: 0.4
	PAUSE :: 0.25
	for {
		walk_route(self, PATROL_ROUTE[:], STEP, PAUSE) or_break
		pause(PAUSE) or_break
	}
}

// Runs alongside `patrol` on the same entity; it only touches rotation and scale.
spin :: proc(self: Entity_Id) {
	turn := tween_by(self, .Rotation, {360, 0, 0, 0}, 1, .Back_Out)
	if !scale_to(self, {1.6, 1.6}, 0.3, .Quadratic_Out) do return
	if !scale_to(self, {1, 1}, 0.6, .Bounce_Out) do return
	wait_tween(turn)
}

ALARM_OFF :: rl.Color{90, 20, 20, 255}
ALARM_ON  :: rl.RED

// Stepping on the button sinks it and makes another entity, the alarm light, blink.
trap_button :: proc(self: Entity_Id) {
	blink_alarm(self, "alarm_light")
}

// Wired to an alarm that doesn't exist: find logs a warning and the script stops.
broken_trap_button :: proc(self: Entity_Id) {
	blink_alarm(self, "missing_alarm")
}

blink_alarm :: proc(button: Entity_Id, light_name: string, loc := #caller_location) {
	light := find(light_name, loc)
	if !entity_alive(light) do return // find already logged a warning

	set_sprite_tag_of(button, .Down)
	for _ in 0..<6 {
		set_tint(light, ALARM_ON)
		pause(0.25) or_break
		set_tint(light, ALARM_OFF)
		pause(0.25) or_break
	}
	set_tint(light, ALARM_OFF)
	set_sprite_tag_of(button, .Up)
}

// Each line stays up until the player presses Z.
villager_talk :: proc(self: Entity_Id) {
	if !say("Hello there! You can walk around with the arrow keys.", "Villager") do return
	say("Press Z while facing something to talk to it. I hear the buttons down south do something...", "Villager")
}

// Flashes the screen a random bright color for a quarter second.
flash_random :: proc(self: Entity_Id) {
	color := rl.ColorFromHSV(rand.float32_range(0, 360), 0.8, 1)
	flash_screen(color, 0.25)
}

vanish :: proc(self: Entity_Id) {
	if !scale_to(self, {1.8, 1.8}, 0.25, .Back_Out) do return
	if !fade_to(self, 0, 0.6) do return
	destroy_entity(self)
}

// A chest's trigger script: opens the box, gives `items` and says so. The box
// can't be opened again: its trigger is cleared and the datum is set, so the
// level spawns it opened from then on.
items_in_a_box :: proc(self: Entity_Id, datum: Chest_Datum, items: ..rules.Item_Name) {
	set_game_data(datum, true)
	clear_trigger(self)
	set_sprite_tag_of(self, .Opened)
	if len(items) == 0 {
		say("Ooh, nothing!")
	} else {
		get_items(..items)
	}
}

monster_in_a_box :: proc(self: Entity_Id, datum: Chest_Datum, encounter: rules.Encounter_Name, items: ..rules.Item_Name) {
	set_game_data(datum, true)
	clear_trigger(self)
	set_sprite_tag_of(self, .Opened)
	say("Monster in a box!")
	start_encounter(encounter)
	if !battle_done() do return
	// say nothing if no items in this case
	if len(items) > 0 do get_items(..items)
}

start_encounter :: proc(name: rules.Encounter_Name) {
	log.infof("starting encounter %v", name)
	battle_stage(name) // tell battle to initialize from encounter. Must happen on main thread to load baddy sprites
		// fade_screen(0, .5)
		// pause(.5)
		// battle.paused = false
	spawn(proc(_: Entity_Id) {
		if !fade_screen(1, .5) do return
		if !battle_active() do return // wait until initialization is done
		play_music(.Battle)
		if !fade_screen(0, .5) do return
		if !pause(.5) do return
		battle.paused = false
	}, name = "battle start")
}

