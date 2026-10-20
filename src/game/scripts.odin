package game

import rl "vendor:raylib"
import "../engine"

// Flash the player red, slide away, wait, then restore the player's tint.
glide_away :: proc(self: engine.Entity_Id) {
	player := engine.player()
	engine.set_tint(player, rl.RED)
	engine.move_entity(self, {120, 0}, 1.5, .Quadratic_In_Out)
	engine.pause(2)
	engine.set_tint(player, rl.WHITE)
	engine.move_entity(self, {-120, 0}, 0.5, .Cubic_Out)
}

// Runs for the entity's whole life. The bool results let it stop when cancelled.
patrol :: proc(self: engine.Entity_Id) {
	for {
		engine.move_entity(self, {200, 0}, 2, .Sine_In_Out) or_break
		engine.pause(0.5) or_break
		engine.move_entity(self, {-200, 0}, 2, .Sine_In_Out) or_break
		engine.pause(0.5) or_break
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

	engine.set_scale(button, {1, 0.4})
	for _ in 0..<6 {
		engine.set_tint(light, ALARM_ON)
		engine.pause(0.25) or_break
		engine.set_tint(light, ALARM_OFF)
		engine.pause(0.25) or_break
	}
	engine.set_tint(light, ALARM_OFF)
	engine.scale_to(button, {1, 1}, 0.2, .Back_Out)
}

vanish :: proc(self: engine.Entity_Id) {
	if !engine.scale_to(self, {1.8, 1.8}, 0.25, .Back_Out) do return
	if !engine.fade_to(self, 0, 0.6) do return
	engine.destroy_entity(self)
}
