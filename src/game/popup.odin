package game

import "core:fmt"
import "core:log"
import sa "core:container/small_array"
import rl "vendor:raylib"

@(private = "file")
MAX_POPUPS :: 32
@(private = "file")
POPUP_TIME :: f32(1)

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

popup :: proc(eid: Entity_Id, color: rl.Color, format: string, args: ..any, dmg := false) {
	pos := entity_pos(eid) - {0, TILE_SIZE / 2}
	p := Popup{pos = pos, color = color, dmg = dmg}
	fmt.bprintf(p.text[:len(p.text) - 1], format, ..args)
  if !sa.push(&popups, p) do log.warnf("Too many popups; dropped %q", p.text)
}
