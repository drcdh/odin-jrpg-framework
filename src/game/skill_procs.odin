package game

import "core:log"
import rl "vendor:raylib"

get_single_target :: proc(target_selection: Target_Selection) -> (target_idx: int, ok: bool) {
	#partial switch ts in target_selection {
	case Target_One_Baddy:
		target_idx, ok = battle.baddies[ts.i], true
	case Target_One_Player:
		target_idx, ok = battle.players[ts.i], true
	}
	if !ok do log.warnf("get_single_target got %v", target_selection)
	return
}

skill_proc_slash :: proc(skill_play: Battle_Skill_Play) {
	ACC    :: Stat(100)
	ATTACK :: Attack_Data{power = 100}
	NAME   :: "Slash"
	SOUND  :: Sound_Name.Whack

	say(NAME, hurry=true, justify=.Center, lines=1, line_width=-1, pause=1)
	actor := battle.combatants[skill_play.actor_idx]
	actor_eid := actor.eid

	target_idx: int
	ok: bool
	if target_idx, ok = get_single_target(skill_play.targets); !ok do return
	target := battle.combatants[target_idx]
	target_eid := target.eid

	ATTACK_TIME :: .25 // time to animate approach and retreat
	PARTY_DX :: 2 // distance players move horizontally in tiles
	if actor.team == .Baddy {
		move_entity(actor_eid, {1, 0}, ATTACK_TIME)
	} else {
		set_sprite_tag_of(actor_eid, .RArm)
		freeze_anim(actor_eid, 1)
		wait_all(tween_jump(actor_eid, -PARTY_DX, 1, ATTACK_TIME))
		set_sprite_tag_of(actor_eid, .Walk)
		freeze_anim(actor_eid, 1)
	}

	hit_result := attack_hit(actor^, target^, ACC)

	run_anim(target_eid, .Slash, flip_x = target.team == .Player)

	switch hit_result{
	case .Evade:
		// play_sound(.Ting)
		popup_2(target_eid, rl.GRAY, "Eva", dmg=true)
	case .Hit:
		play_sound(SOUND)
		damage, _ := attack_damage(actor^, target^, ATTACK)
		popup_2(target_eid, rl.WHITE, "%d", damage, dmg=true)
	case .Miss:
		// play_sound(.Whiff)
		popup_2(target_eid, rl.GRAY, "Mi", dmg=true)
	}

	if actor.team == .Baddy {
		move_entity(actor_eid, {-1, 0}, ATTACK_TIME)
	} else {
		set_sprite_tag_of(actor_eid, .Walk)
		play_anim(actor_eid)
		move_entity(actor_eid, {PARTY_DX, 0}, ATTACK_TIME)
		update_character_sprite(actor^)
	}

	// if hit_result == .Hit {
	// 	pause(.5)
	// 	wake_up(target) // TODO
	// }
}
