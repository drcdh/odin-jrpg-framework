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
POPUP_GAP :: f32(0.4)

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

battle_effect_popups :: proc(target_eid: Entity_Id, r: Effect_Result) {
	// ignore status changes on downed targets
	new_popups := effect_popups(r, status = !r.downed)
	for p, i in sa.slice(&new_popups) {
		if i > 0 && !pause(POPUP_GAP) do return // pause between popups
		push_battle_popup(target_eid, p)
	}
}

world_menu_effect_popups :: proc(slot: int, r: Effect_Result) {
	new_popups := effect_popups(r, status = !r.downed)
	for &p, i in sa.slice(&new_popups) do push_world_menu_popup(slot, p.color, f32(i) * POPUP_GAP, string(cstring(&p.text[0])), p.dmg)
}

@(private = "file")
push_popup :: proc(p: Popup) {
	if !sa.push(&popups, p) do log.warnf("Too many popups; dropped %q", p.text)
}

@(private = "file")
push_battle_popup :: proc(id: Entity_Id, popup: Popup) {
	popup := popup
	popup.pos = entity_pos(id) - {0, TILE_SIZE / 2}
	push_popup(popup)
}

@(private = "file")
push_world_menu_popup :: proc(slot: int, color: rl.Color, delay: f32, text: string, dmg := false) {
	w := sprite_size(pc_menu_sprite(get_pc_idx(slot))).x / TILE_SIZE
	x, y : f32 = 1.5 + 2.5 * f32(slot) + w / 2, 11.5
	p := Popup{pos = {x*TILE_SIZE, y*TILE_SIZE}, color = color, t = -delay, dmg = dmg}
	copy(p.text[:len(p.text) - 1], text)
	push_popup(p)
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
