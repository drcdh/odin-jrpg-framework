package game

import rl "vendor:raylib"

DEFAULT_CHARGE_MAX :: Ticks(100)

Charge :: struct {
	value: Ticks,
	max:   Ticks,
	delay: Ticks,
}

new_charge :: proc(max: Ticks, value: Ticks = 0, delay: Ticks = 0) -> Charge {
	return {
		value = min(value, max), // cap value at max
		max   = max,
		delay = min(delay, value, max), // cap delay at value (which is capped at max)
	}
}

delay_charge :: proc(charge: ^Charge, delay: Ticks) {
	charge.delay = min(charge.delay + delay, charge.value) // cap delay at value
}

reset_charge :: proc(charge: ^Charge, new_max: Maybe(Ticks) = nil) {
	charge.delay = 0
	charge.value = 0
	charge.max = new_max.? or_else charge.max
}

update_charge :: proc(charge: ^Charge, ticks: Ticks) {
	if ticks >= charge.delay {
		charge.value = min(charge.value + ticks - charge.delay, charge.max) // cap value at max
		charge.delay = 0
	} else {
		charge.delay -= ticks
	}
}

charge_full :: proc(charge: Charge) -> bool {
	return charge.value - charge.delay >= charge.max
}

draw_charge :: proc(origin: [2]f32, charge: Charge, filled_color, delayed_color, empty_color, maxed_color: rl.Color, dim := [2]f32{16, 4}) {
	if charge.max == 0 do return // ignore cantrips
	w, h := dim.x, dim.y
	x, y := origin.x, origin.y + (8-h)/2 // center in line of 8px text
	if !charge_full(charge) {
		rv, rn := relative_gauge_values(charge)
		rl.DrawRectangleRec({x, y, w, h}, empty_color)
		rl.DrawRectangleRec({x, y, w * rv, h}, delayed_color)
		rl.DrawRectangleRec({x, y, w * rn, h}, filled_color)
	} else {
		rl.DrawRectangleRec({x, y, w, h}, maxed_color)
	}
	rl.DrawRectangleLinesEx({x, y, w, h}, 1, rl.BLACK) // border
}

@(private = "file")
relative_gauge_values :: proc(charge: Charge) -> (f32, f32) {
	r_value := f32(charge.value)/f32(charge.max)
	net := max(0, charge.value - charge.delay)
	r_net := f32(net)/f32(charge.max)
	return r_value, r_net
}
