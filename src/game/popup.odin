package game

import "core:fmt"
import "core:log"
import sa "core:container/small_array"
import rl "vendor:raylib"

@(private = "file")
MAX_POPUPS :: 32
@(private = "file")
POPUP_TIME :: f32(1)
POPUP_GAP :: f32(0.4) // seconds between one target's popups

@(private = "file")
Popup :: struct {
	pos:   [2]f32, // world pixels
	text:  [16]u8, // NUL-terminated
	color: rl.Color,
	t:     f32, // seconds since it appeared; negative while it waits
	dmg:   bool, // use damage_font
}

@(private = "file")
Popups :: sa.Small_Array(MAX_POPUPS, Popup)

@(private = "file")
popups: Popups

popups_init :: proc() {
	sa.clear(&popups)
}

popups_shutdown :: proc() {
	sa.clear(&popups)
}

clear_popups :: proc() {
	sa.clear(&popups)
}

popup_count :: proc() -> int {
	return sa.len(popups)
}

popups_update :: proc(dt: f32) {
	for i := 0; i < sa.len(popups); {
		p := sa.get_ptr(&popups, i)
		p.t += dt
		if p.t >= POPUP_TIME {
			sa.ordered_remove(&popups, i)
		} else {
			i += 1
		}
	}
}

draw_popups :: proc() {
	for &p in sa.slice(&popups) {
		if p.t < 0 do continue
		k := p.t / POPUP_TIME
		color := p.color
		color.a = u8(255 * (1 - k))
		at := p.pos / TILE_SIZE
		draw_text_center(at.x, at.y - 0.5 * k, cstring(&p.text[0]), color, font = p.dmg ? .Damage : .Normal)
	}
}

// Pops up `r` over `c`'s entity, POPUP_GAP apart, without blocking. Returns
// how many popups there are.
show_effect_popups :: proc(c: Character, r: Effect_Result) -> int {
	// ignore status changes on downed targets
	new_popups := effect_popups(r, status = !r.downed)
	pos := entity_pos(c.eid) - {0, TILE_SIZE / 2}
	for &p, i in sa.slice(&new_popups) {
		p.pos = pos
		p.t = -f32(i) * POPUP_GAP
		push_popup(p)
	}
	return sa.len(new_popups)
}

@(private = "file")
push_popup :: proc(p: Popup) {
	if !sa.push(&popups, p) do log.warnf("Too many popups; dropped %q", p.text)
}

// The popups for `r`, in order: the hit or HP change, then levels, then
// status (unless `status` is false).
@(private = "file")
effect_popups :: proc(r: Effect_Result, status := true) -> (popups: Popups) {
	popup :: proc(popups: ^Popups, color: rl.Color, format: string, args: ..any, dmg := false) {
		p := Popup{color = color, dmg = dmg}
		fmt.bprintf(p.text[:len(p.text) - 1], format, ..args)
		sa.push(popups, p)
	}

	switch r.hit {
	case .Miss:  popup(&popups, rl.GRAY, "Mi", dmg=true)
	case .Evade: popup(&popups, rl.GRAY, "Eva", dmg=true)
	case .Hit:
	}
	if r.hp_change < 0 do popup(&popups, rl.WHITE, "%d", -r.hp_change, dmg=true)
	if r.hp_change > 0 do popup(&popups, rl.GREEN, "%d", r.hp_change, dmg=true)
	if r.levels > 0 do popup(&popups, rl.PURPLE, "%d", r.levels, dmg=true)
	if s, ok := r.status.?; ok && status {
		switch r.status_result {
		case .None:
		case .Added:         popup(&popups, rl.RED, "%v", s) // TODO: status animations?
		case .Ineffective:   popup(&popups, rl.PURPLE, "Ine", dmg=true)
		case .Resisted:      popup(&popups, rl.PURPLE, "Res", dmg=true)
		case .Removed:       popup(&popups, rl.GREEN, "Cur", dmg=true)
		case .Remove_Missed: popup(&popups, rl.PURPLE, "Mi", dmg=true)
		}
	}
	return
}
