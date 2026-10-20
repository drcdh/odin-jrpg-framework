package game

import "core:math/rand"
import rl "vendor:raylib"
import "../engine"

// Flash the player red, slide away, wait, then restore the player's tint.
glide_away :: proc(self: engine.Entity_Id) {
	player := engine.player()
	engine.set_tint(player, rl.RED)
	engine.move_entity(self, {4, 0}, 1.0, .Quadratic_In_Out)
	engine.pause(2)
	engine.set_tint(player, rl.WHITE)
	engine.move_entity(self, {-4, 0}, 0.5, .Cubic_Out)
}

// Runs for the entity's whole life. Steps a tile, waits 0.25 s, steps again,
// including at the turnarounds. The bool results let it stop when cancelled.
patrol :: proc(self: engine.Entity_Id) {
	STEP  :: 0.4
	PAUSE :: 0.25
	for {
		engine.walk_entity(self, {5, 0}, STEP, PAUSE) or_break
		engine.pause(PAUSE) or_break
		engine.walk_entity(self, {-5, 0}, STEP, PAUSE) or_break
		engine.pause(PAUSE) or_break
	}
}

// Corners of the route patroller's loop. Adjacent vertices (and the last and
// first) differ in only one dimension.
PATROL_ROUTE := [?]engine.Tile{{15, 1}, {18, 1}, {18, 4}, {17, 4}, {17, 7}, {15, 7}}

// Loops the route forever with the same rhythm as `patrol`: a tile every
// 0.4 s with a 0.25 s pause between moves, corners included.
patrol_route :: proc(self: engine.Entity_Id) {
	STEP  :: 0.4
	PAUSE :: 0.25
	for {
		engine.walk_route(self, PATROL_ROUTE[:], STEP, PAUSE) or_break
		engine.pause(PAUSE) or_break
	}
}

// Runs alongside `patrol` on the same entity; it only touches rotation and scale.
spin :: proc(self: engine.Entity_Id) {
	turn := engine.tween_by(self, .Rotation, {360, 0, 0, 0}, 1, .Back_Out)
	if !engine.scale_to(self, {1.6, 1.6}, 0.3, .Quadratic_Out) do return
	if !engine.scale_to(self, {1, 1}, 0.6, .Bounce_Out) do return
	engine.wait_tween(turn)
}

ALARM_OFF :: rl.Color{90, 20, 20, 255}
ALARM_ON  :: rl.RED

// Stepping on the button sinks it and makes another entity, the alarm light, blink.
trap_button :: proc(self: engine.Entity_Id) {
	blink_alarm(self, "alarm_light")
}

// Wired to an alarm that doesn't exist: find logs a warning and the script stops.
broken_trap_button :: proc(self: engine.Entity_Id) {
	blink_alarm(self, "missing_alarm")
}

blink_alarm :: proc(button: engine.Entity_Id, light_name: string, loc := #caller_location) {
	light := engine.find(light_name, loc)
	if !engine.entity_alive(light) do return // find already logged a warning

	engine.set_sprite_tag_of(button, .Down)
	for _ in 0..<6 {
		engine.set_tint(light, ALARM_ON)
		engine.pause(0.25) or_break
		engine.set_tint(light, ALARM_OFF)
		engine.pause(0.25) or_break
	}
	engine.set_tint(light, ALARM_OFF)
	engine.set_sprite_tag_of(button, .Up)
}

// Each line stays up until the player presses Z.
villager_talk :: proc(self: engine.Entity_Id) {
	if !engine.say("Hello there! You can walk around with WASD or the arrow keys.", "Villager") do return
	engine.say("Press Z while facing something to talk to it. I hear the buttons down south do something...", "Villager")
}

// Flashes the screen a random bright color for a quarter second.
flash_random :: proc(self: engine.Entity_Id) {
	color := rl.ColorFromHSV(rand.float32_range(0, 360), 0.8, 1)
	engine.flash_screen(color, 0.25)
}

vanish :: proc(self: engine.Entity_Id) {
	if !engine.scale_to(self, {1.8, 1.8}, 0.25, .Back_Out) do return
	if !engine.fade_to(self, 0, 0.6) do return
	engine.destroy_entity(self)
}
