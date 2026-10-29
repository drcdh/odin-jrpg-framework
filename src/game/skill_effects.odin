package game

import sa "core:container/small_array"
import "core:fmt"
import rl "vendor:raylib"

// Skill effects as the player sees them. do_skill works out the effect
// and changes the characters; these procs play the skill's sound and animate
// the result, which differs between the world menu and battles.

Skill_Context :: enum {
	World_Menu,
	Battle,
}

// `actor` is nil for an item. The target is a party slot.
do_skill :: proc(actor: ^Character, target_party_idx: int, skill_name: Skill_Name, ctx: Skill_Context) -> (r: Effect_Result) {
	target := get_party_member(target_party_idx)
	skill := skills[skill_name]
	r = do_effect_character(actor, target, skill.effect_data, skill.effect_type)
	play_sound(skill.sound)
	switch ctx {
	case .World_Menu: show_effect_in_world_menu(target_party_idx, r)
	case .Battle:     // TODO: battle presentation
	}
	return
}

// Seconds between one result's popups.
POPUP_GAP :: f32(0.4)

// One line of text that shows part of an Effect_Result. It allocates
// nothing, so scripts can make them too.
Effect_Popup :: struct {
	text:  [16]u8, // NUL-terminated
	color: rl.Color,
}

Effect_Popups :: sa.Small_Array(4, Effect_Popup)

// The popups for `r`, in order: the hit or HP change, then levels, then
// status (unless `status` is false).
effect_popups :: proc(r: Effect_Result, status := true) -> (popups: Effect_Popups) {
	popup :: proc(popups: ^Effect_Popups, color: rl.Color, format: string, args: ..any) {
		p := Effect_Popup{color = color}
		fmt.bprintf(p.text[:len(p.text) - 1], format, ..args)
		sa.push(popups, p)
	}

	switch r.hit {
	case .Miss:  popup(&popups, rl.GRAY, "Miss!")
	case .Evade: popup(&popups, rl.GRAY, "Evade!")
	case .Hit:
	}
	if r.hp_change < 0 do popup(&popups, rl.WHITE, "%d", -r.hp_change)
	if r.hp_change > 0 do popup(&popups, rl.GREEN, "%d", r.hp_change)
	if r.levels > 0 do popup(&popups, rl.PURPLE, "+%d LV", r.levels)
	if s, ok := r.status.?; ok && status {
		switch r.status_result {
		case .None:
		case .Added:         popup(&popups, rl.RED, "%v", s)
		case .Ineffective:   popup(&popups, rl.PURPLE, "Ineff!")
		case .Resisted:      popup(&popups, rl.PURPLE, "Resist!")
		case .Removed:       popup(&popups, rl.GREEN, "Cured")
		case .Remove_Missed: popup(&popups, rl.PURPLE, "Miss")
		}
	}
	return
}

// Popups over the target in the Targeting pane, POPUP_GAP apart.
@(private = "file")
show_effect_in_world_menu :: proc(slot: int, r: Effect_Result) {
	popups := effect_popups(r)
	for &p, i in sa.slice(&popups) do world_menu_popup(slot, p.color, f32(i) * POPUP_GAP, string(cstring(&p.text[0])))
}
