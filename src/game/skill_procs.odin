package game

// import "core:log"
import rl "vendor:raylib"

Skill_Proc :: #type proc(actor: ^Character, targets: Target_Selection)

skill_proc_potion :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_constant_heal_single_target("Potion", 50, actor, targets)
}

skill_proc_super_potion :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_constant_heal_single_target("Super Potion", 500, actor, targets)
}

skill_proc_slash :: proc(actor: ^Character, targets: Target_Selection) {
	ACC    :: Stat(100)
	ATTACK :: Attack_Data{power = 100}
	NAME   :: "Slash"
	SOUND  :: Sound_Name.Whack

	say(NAME, hurry=true, justify=.Center, lines=1, line_width=-1, pause=1)

	target_idx := get_single_target(targets)
	target := battle.combatants[target_idx]
	target_eid := target.eid

	lunge_forward(actor^)

	hit_result := attack_hit(actor^, target^, ACC)

	switch hit_result{
	case .Evade:
		// play_sound(.Ting)
	case .Hit:
		play_sound(SOUND)
	case .Miss:
		// play_sound(.Whiff)
	}

	// after play_sound because it doesn't block but run_anim does
	run_anim(target_eid, .Slash, flip_x = target.team == .Player)

	switch hit_result{
	case .Evade:
		popup_2(target_eid, rl.GRAY, "Eva", dmg=true)
	case .Hit:
		damage, _ := attack_damage(actor^, target^, ATTACK)
		take_damage(target, damage)
		popup_2(target_eid, rl.WHITE, "%d", damage, dmg=true)
	case .Miss:
		popup_2(target_eid, rl.GRAY, "Mi", dmg=true)
	}

	walk_back(actor^)

	// if hit_result == .Hit {
	// 	pause(.5)
	// 	wake_up(target) // TODO
	// }
}

@(private = "file")
skill_proc_constant_heal_single_target :: proc(name: string, constant: int, actor: ^Character, targets: Target_Selection) {
	say(name, hurry=true, justify=.Center, lines=1, line_width=-1, pause=1)
	target_idx := get_single_target(targets)
	target := battle.combatants[target_idx]
	target_eid := target.eid
	item_forward(actor^)
	play_sound(.Warp)
	run_anim(target_eid, .Heal)
	restore_hitpoints(target, constant)
	popup_2(target_eid, rl.GREEN, "%d", constant, dmg=true)
	walk_back(actor^)
}

@(private = "file")
PLAYER_DX :: 2 // distance players move horizontally in tiles

@(private = "file")
lunge_forward :: proc(actor: Character) {
	TIME :: .25 // time to animate approach and retreat
	actor_eid := actor.eid
	if actor.team == .Baddy {
		move_entity(actor_eid, {1, 0}, TIME)
	} else {
		set_sprite_tag_of(actor_eid, .RArm)
		freeze_anim(actor_eid, 1)
		wait_all(tween_jump(actor_eid, -PLAYER_DX, 1, TIME))
		set_sprite_tag_of(actor_eid, .Walk)
		freeze_anim(actor_eid, 1)
	}
}

@(private = "file")
item_forward :: proc(actor: Character) {
	TIME :: .5 // seconds
	actor_eid := actor.eid
	if actor.team == .Baddy {
		move_entity(actor_eid, {1, 0}, TIME)
	} else {
		set_sprite_tag_of(actor_eid, .Walk)
		play_anim(actor_eid)
		move_entity(actor_eid, {-PLAYER_DX, 0}, TIME)
		set_sprite_tag_of(actor_eid, .Cheer)
		freeze_anim(actor_eid, 1)
	}
}

@(private = "file")
walk_back :: proc(actor: Character) {
	TIME :: .5 // seconds
	actor_eid := actor.eid
	if actor.team == .Baddy {
		move_entity(actor_eid, {-1, 0}, TIME)
	} else {
		set_sprite_tag_of(actor_eid, .Walk)
		play_anim(actor_eid)
		move_entity(actor_eid, {PLAYER_DX, 0}, TIME)
		update_character_sprite(actor)
	}
}
