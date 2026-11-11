package game

import "core:log"
import rl "vendor:raylib"

Skill_Proc :: #type proc(actor: ^Character, targets: Target_Selection)

skill_proc_potion :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_constant_heal_single_target_item("Potion", 50, actor, targets)
}

skill_proc_super_potion :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_constant_heal_single_target_item("Super Potion", 500, actor, targets)
}

skill_proc_antidote :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_remove_status_single_target_item("Antidote", 100, .Poison, actor, targets)
}

skill_proc_poison_mushroom :: proc(actor: ^Character, targets: Target_Selection) {
	say("Poison Mushroom", hurry=true, justify=.Center, lines=1, line_width=-1, pause=1)
	target_idx := get_single_target(targets)
	target := battle.combatants[target_idx]
	target_eid := target.eid
	item_forward(actor^)
	play_sound(.Warp)
	run_anim(target_eid, .Wave_Poison)
	restore_hitpoints(target, 20)
	popup_2(target_eid, rl.GREEN, "%d", 20, dmg=true)
	try_add_status(target, sts_acc=100, status=.Poison)
	walk_back(actor^)
}

skill_proc_smack :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_basic_attack("Smack", 100, {power = 60}, .Whack, .Smack, actor, targets)
}

skill_proc_punch :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_basic_attack("Punch", 100, {power = 80}, .Whack, .Smack, actor, targets)
}

skill_proc_smash :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_basic_attack("Smash", 100, {power = 100}, .Whack, .Smack, actor, targets)
}

skill_proc_slash :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_basic_attack("Slash", 100, {power = 100}, .Whack, .Slash, actor, targets)
}

skill_proc_bite :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_basic_attack("Bite", 100, {power = 150}, .Whack, .Ffvi_Stars, actor, targets)
}

skill_proc_stab :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_basic_attack("Stab", 100, {power = 80, pierce = 50}, .Whack, .Stab, actor, targets)
}

skill_proc_wild_swing :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_basic_attack("Wild Swing", 100, {power = 200}, .Whack, .Slash, actor, targets/*, risk = 300*/)
}

skill_proc_slash_all :: proc(actor: ^Character, targets: Target_Selection) {
	ACC    :: Stat(100)
	ATTACK :: Attack_Data{power = 100}
	NAME   :: "Slash All"
	SOUND  :: Sound_Name.Whack
	SPRITE :: Sprite_Name.Slash
	skill_proc_basic_attack_each(NAME, ACC, ATTACK, SOUND, SPRITE, actor, targets)
}

skill_proc_fire :: proc(actor: ^Character, targets: Target_Selection) {
	skill_proc_basic_attack("Fire", 100, {psy_power = 80}, .Warp, .Small_Flame, actor, targets)
}

// ********************
// ********************

@(private = "file")
skill_proc_constant_heal_single_target_item :: proc(name: string, constant: int, actor: ^Character, targets: Target_Selection) {
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
skill_proc_remove_status_single_target_item :: proc(name: string, sts_acc: int, status: Status_Name, actor: ^Character, targets: Target_Selection) {
	say(name, hurry=true, justify=.Center, lines=1, line_width=-1, pause=1)
	target_idx := get_single_target(targets)
	target := battle.combatants[target_idx]
	target_eid := target.eid
	item_forward(actor^)
	play_sound(.Warp)
	run_anim(target_eid, .Heal)
	try_remove_status(target, sts_acc=sts_acc, status=.Poison)
	walk_back(actor^)
}

@(private = "file")
skill_proc_basic_attack :: proc(name: string, acc: Stat, attack: Attack_Data, sound: Sound_Name, sprite: Sprite_Name, actor: ^Character, targets: Target_Selection) {
	say(name, hurry=true, justify=.Center, lines=1, line_width=-1, pause=1)

	target_idx := get_single_target(targets)
	target := battle.combatants[target_idx]
	target_eid := target.eid

	lunge_forward(actor^)

	hit_result := attack_hit(actor^, target^, acc)

	switch hit_result{
	case .Evade:
		// play_sound(.Ting)
	case .Hit:
		play_sound(sound)
	case .Miss:
		// play_sound(.Whiff)
	}

	// after play_sound because it doesn't block but run_anim does
	run_anim(target_eid, .Slash, flip_x = target.team == .Player)

	switch hit_result{
	case .Evade:
		popup_2(target_eid, rl.GRAY, "Eva", dmg=true)
	case .Hit:
		damage, _ := attack_damage(actor^, target^, attack)
		take_damage(target, damage)
		popup_2(target_eid, rl.WHITE, "%d", damage, dmg=true)
	case .Miss:
		popup_2(target_eid, rl.GRAY, "Mi", dmg=true)
	}

	walk_back(actor^)
}

skill_proc_basic_attack_each :: proc(name: string, acc: Stat, attack: Attack_Data, sound: Sound_Name, sprite: Sprite_Name, actor: ^Character, targets: Target_Selection) {
	say(name, hurry=true, justify=.Center, lines=1, line_width=-1, pause=1)

	target_team: [dynamic]int
	switch get_team_target(targets) {
	case .Baddy:
		target_team = battle.baddies
	case .Player:
		target_team = battle.players
	case .None:
		log.errorf("got Team.None in skill proc")
		return
	}

	// TODO: consolidate into a struct
	targets: [dynamic]^Character
	hit_results: [dynamic]Hit_Result
	damage: [dynamic]int

	for c_idx in target_team {
		target := battle.combatants[c_idx]
		if downed(target^) do continue
		append(&targets, target)
		hit_result := attack_hit(actor^, target^, acc)
		append(&hit_results, hit_result)
		append(&damage, 0 if hit_result != .Hit else attack_damage(actor^, target^, attack))
	}

	lunge_forward(actor^)

	for target, i in targets {
		switch hit_results[i] {
		case .Evade:
			// play_sound(.Ting)
		case .Hit:
			play_sound(sound)
		case .Miss:
			// play_sound(.Whiff)
		}
		run_anim(target.eid, .Slash, flip_x = target.team == .Player)
	}

	for hit_result, i in hit_results {
		target := targets[i]
		target_eid := target.eid
		switch hit_result {
		case .Evade:
			popup_2(target_eid, rl.GRAY, "Eva", dmg=true)
		case .Hit:
			damage, _ := attack_damage(actor^, target^, attack)
			take_damage(target, damage)
			popup_2(target_eid, rl.WHITE, "%d", damage, dmg=true)
		case .Miss:
			popup_2(target_eid, rl.GRAY, "Mi", dmg=true)
		}
	}

	walk_back(actor^)
	}

// ********************
// ********************

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
