package game

import "core:log"

get_single_target :: proc(target_selection: Target_Selection) -> (target_idx: int, ok: bool) {
	#partial switch target_selection {
	case Target_One_Baddy:
		target_idx, ok = battle.baddies[target_selection.i], true
	case Target_One_Player:
		target_idx, ok = battle.players[target_selection.i], true
	}
	if !ok do log.warningf("get_single_target got %v", target_selection)
}

skill_proc_slash :: proc(skill_play: Battle_Skill_Play) {
	say("Slash", hurry=true, justify=.Center, lines=1, line_width=-1, pause=1)
	actor := battle.combatants[skill_play.actor_idx]
	actor_eid = actor.eid
	if target_idx, ok := get_single_target(skill_play.targets); !ok do return
	target := battle.combatants[target_idx]
	target_eid := target.eid



	if actor.team == .Baddy {
		move_entity(actor_eid, {1, 0}, ATTACK_TIME)
	} else {
		set_sprite_tag_of(actor_eid, .RArm)
		freeze_anim(actor_eid, 1)
		wait_all(tween_jump(actor_eid, -PARTY_DX, 1, ATTACK_TIME))
		set_sprite_tag_of(actor_eid, .Walk)
		freeze_anim(actor_eid, 1)
	}

	play_skill_anim(target_eid, .Slash, flip_x = target.team == .Player)
}
