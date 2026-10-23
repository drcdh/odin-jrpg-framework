package game

import "core:fmt"
import rl "vendor:raylib"

import "../rules"

// Skill effects as the player sees them. rules.do_skill works out the effect
// and changes the characters; these procs play the skill's sound and animate
// the result, which differs between the world menu and battles.

Skill_Context :: enum {
	World_Menu,
	Battle,
}

// `actor` is nil for an item. The target is a party slot.
do_skill :: proc(actor: ^rules.Character, target_party_idx: int, skill: rules.Skill_Name, ctx: Skill_Context) -> (r: rules.Effect_Result) {
	target := rules.get_party_member(target_party_idx)
	r = rules.do_skill(actor, target, rules.skills[skill])
	if s, ok := skill_sounds[skill].?; ok do play_sound(s)
	switch ctx {
	case .World_Menu: show_effect_in_world_menu(target_party_idx, r)
	case .Battle:     // TODO: battle presentation
	}
	return
}

// Seconds between one result's popups.
@(private = "file")
POPUP_GAP :: f32(0.4)

// Popups over the target in the Targeting pane: the hit or HP change, then
// levels, then status.
@(private = "file")
show_effect_in_world_menu :: proc(slot: int, r: rules.Effect_Result) {
	delay: f32
	popup :: proc(slot: int, color: rl.Color, delay: ^f32, format: string, args: ..any) {
		world_menu_popup(slot, color, delay^, fmt.tprintf(format, ..args))
		delay^ += POPUP_GAP
	}

	switch r.hit {
	case .Miss:  popup(slot, rl.GRAY, &delay, "Miss!")
	case .Evade: popup(slot, rl.GRAY, &delay, "Evade!")
	case .Hit:
	}
	if r.hp_change < 0 do popup(slot, rl.WHITE, &delay, "%d", -r.hp_change)
	if r.hp_change > 0 do popup(slot, rl.GREEN, &delay, "%d", r.hp_change)
	if r.levels > 0 do popup(slot, rl.PURPLE, &delay, "+%d LV", r.levels)
	if s, ok := r.status.?; ok {
		switch r.status_result {
		case .None:
		case .Added:         popup(slot, rl.RED, &delay, "%v", s)
		case .Ineffective:   popup(slot, rl.PURPLE, &delay, "Ineff!")
		case .Resisted:      popup(slot, rl.PURPLE, &delay, "Resist!")
		case .Removed:       popup(slot, rl.GREEN, &delay, "Cured")
		case .Remove_Missed: popup(slot, rl.PURPLE, &delay, "Miss")
		}
	}
}
