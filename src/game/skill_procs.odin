package game

// import "core:log"
import "core:math/rand"
import rl "vendor:raylib"

Skill_Proc :: #type proc(actor: ^Character, targets: []^Character)

skill_proc_potion :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_heal_some("Potion", {acc=100, constant=50}, .Warp, .Heal, actor, targets)
}

skill_proc_super_potion :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_heal_some("Super Potion", {acc=100, constant=500}, .Warp, .Heal, actor, targets)
}

skill_proc_antidote :: proc(actor: ^Character, targets: []^Character) {
	assert(len(targets) == 1)
	skill_proc_remove_status_single_target_item("Antidote", 100, .Poison, actor, targets[0])
}

skill_proc_poisonous_mushroom :: proc(actor: ^Character, targets: []^Character) {
	assert(len(targets) == 1)
	skill_say("Poisonous Mushroom")
	target := targets[0]
	target_eid := target.eid
	item_forward(actor^)
	play_sound(.Warp)
	run_anim(target_eid, .Wave_Poison)
	restore_hitpoints(target, 20)
	popup(target_eid, rl.GREEN, "%d", 20, dmg=true)
	try_add_status(actor, target, sts_acc=100, status=.Poison)
	walk_back(actor^)
}

skill_proc_level_up :: proc(actor: ^Character, targets: []^Character) {
	assert(len(targets) == 1)
	target := targets[0]
	target_eid := target.eid
	item_forward(actor^)
	play_sound(.Warp)
	run_anim(target_eid, .Heal)
	set_level(target, target.level + 1) // also sets skills
	popup(target_eid, rl.PURPLE, "%d", 1, dmg=true)
	walk_back(actor^)
}

skill_proc_suicide :: proc(actor: ^Character, targets: []^Character) {
	assert(len(targets) == 1)
	target := targets[0]
	target_eid := target.eid
	item_forward(actor^)
	play_sound(.Warp)
	run_anim(target_eid, .Wave_Zombie)
	instakill(target)
	walk_back(actor^)
}

skill_proc_small_smoke_bomb :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Small Smoke Bomb", {stg_acc=100, stagger=50, int_acc=90}, .Warp, .Wave_Blind, actor, targets)
}

skill_proc_smack :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Smack", {acc=100, power = 60}, .Whack, .Smack, actor, targets)
}

skill_proc_punch :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Punch", {acc=100, power = 80}, .Whack, .Smack, actor, targets)
}

skill_proc_smash :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Smash", {acc=100, power = 100}, .Whack, .Smack, actor, targets)
}

skill_proc_slash :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Slash", {acc=100, power = 100}, .Whack, .Slash, actor, targets)
}

skill_proc_bite :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Bite", {acc=100, power = 150}, .Whack, .Ffvi_Stars, actor, targets)
}

skill_proc_stab :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Stab", {acc=100, power = 80, pierce = 50}, .Whack, .Stab, actor, targets)
}

skill_proc_wild_swing :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Wild Swing", {acc=100, power = 200}, .Whack, .Slash, actor, targets/*, risk = 300*/)
}

skill_proc_slash_all :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Slash All", {acc=100, power = 100}, .Whack, .Slash, actor, targets)
}

skill_proc_quake_smash :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Quake Smash", {acc=100, power = 300}, .Whack, .Smack, actor, targets)
}

skill_proc_tickle :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Tickle", {stg_acc=30, stagger=10, int_acc=10}, .Warp, .Ffvi_Stars, actor, targets)
}

skill_proc_tangle :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Tangle", {acc=100, psy_power=100, stg_acc=100, stagger=100, int_acc=10}, .Warp, .Green_Swirl, actor, targets)
}

skill_proc_pommel_strike :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Pommel Strike", {acc=100, power=20, stg_acc=100, stagger=50}, .Whack, .Smack, actor, targets, {{100, .Confuse}})
}

skill_proc_plague_bite :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Plague Bite", {acc=100, power=150}, .Whack, .Ffvi_Stars, actor, targets, {{100, .Poison}})
}

skill_proc_fire :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Fire", {acc=100, psy_power = 100}, .Warp, .Small_Flame, actor, targets)
}

skill_proc_gust :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Gust", {acc=100, psy_power = 10, stg_acc=90, stagger=10, int_acc=2}, .Warp, .Blue_Swirl, actor, targets)
}

skill_proc_frost :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Frost", {acc=100, psy_power = 80, pierce=30, stg_acc=75, stagger=20}, .Warp, .Blue_Stars, actor, targets)
}

skill_proc_heal :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_heal_some("Heal", {acc=100, psy_power=100}, .Warp, .Heal, actor, targets)
}

skill_proc_heal_all :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_heal_some("Heal All", {acc=100, psy_power=50}, .Warp, .Heal, actor, targets)
}

skill_proc_healing_hymn :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_heal_some("Heal Hymn", {acc=100, psy_power=70}, .Warp, .Heal, actor, targets)
}

skill_proc_mind_control :: proc(actor: ^Character, targets: []^Character) {
	assert(len(targets) == 1)
	// skill_proc_basic_attack_some("Mind Control", {}, .Warp, .Heal, actor, targets, {{100, .Control}})
	skill_proc_add_status("Mind Control", .Control, 100, .Warp, .Heal, actor, targets)
}

skill_proc_ultimagnitude_9000 :: proc(actor: ^Character, targets: []^Character) {
	name := "Ultimagnitude 9000"
	attack := Attack_Data{acc=200, power=1000, psy_power=1000, pierce=50, psy_pierce=50}
	flashing := spawn(proc(_: Entity_Id) {
		end := time() + 5 // seconds
		for time() < end {
			color := rl.Color{
				u8(rand.int_max(256)),
				u8(rand.int_max(256)),
				u8(rand.int_max(256)),
				160, // starting alpha; each flash fades from this to clear
			}
			play_sound(.Warp)
			if !flash_screen(color, .25) do return
		}
	})

	skill_say(name)
	lunge_forward(actor^)
	results: [dynamic]ASI_Result; defer clear(&results)
	for target in targets {
		r: ASI_Result
		if downed(target^) {
			append(&results, r)
			continue
		}
		r = try_attack(actor^, target^, attack)
		append(&results, r)
	}

	wait_script(flashing)

	for r, i in results {
		target := targets[i]
		if r.attack_result == .Hit do take_damage(target, r.damage)
		if r.stagger_result == .Hit do stagger_character(target, r.stagger)
		if r.interrupt_result == .Hit do interrupt_windup(target)
		show_attack_results(target, r)
	}

	walk_back(actor^)
}

skill_proc_super_hyper_slash :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Super Hyper Slash", {acc=100, power = 1000, pierce=150}, .Whack, .Slash, actor, targets)
}

skill_proc_debug_stagger :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Debug Stagger", {stg_acc=500, stagger=90}, .Warp, .Wave_Sprain, actor, targets)
}

skill_proc_debug_interrupt :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_basic_attack_some("Debug Interrupt", {int_acc=500}, .Warp, .Wave_Sleep, actor, targets)
}

skill_proc_berserk :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Berserk", .Berserk, 100, .Warp, .Wave_Berserk, actor, targets)
}

skill_proc_blind :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Blind", .Blind, 100, .Warp, .Wave_Blind, actor, targets)
}

skill_proc_confuse :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Confuse", .Confuse, 100, .Warp, .Wave_Confuse, actor, targets)
}

skill_proc_migraine :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Migraine", .Migraine, 100, .Warp, .Wave_Migraine, actor, targets)
}

skill_proc_paralyze :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Paralyze", .Paralyze, 100, .Warp, .Wave_Paralyze, actor, targets)
}

skill_proc_poison :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Poison", .Poison, 100, .Warp, .Wave_Poison, actor, targets)
}

skill_proc_rage :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Rage", .Rage, 100, .Warp, .Wave_Rage, actor, targets)
}

skill_proc_sick :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Sick", .Sick, 100, .Warp, .Wave_Sick, actor, targets)
}

skill_proc_sleep :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Sleep", .Sleep, 100, .Warp, .Wave_Sleep, actor, targets)
}

skill_proc_slow :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Slow", .Slow, 100, .Warp, .Wave_Slow, actor, targets)
}

skill_proc_sprain :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Sprain", .Sprain, 100, .Warp, .Wave_Sprain, actor, targets)
}

skill_proc_zombify :: proc(actor: ^Character, targets: []^Character) {
	skill_proc_add_status("Zombify", .Zombie, 100, .Warp, .Wave_Zombie, actor, targets)
}

// ********************
// ********************

@(private = "file")
skill_proc_heal_some :: proc(name: string, heal_data: Heal_Data, sound: Sound_Name, sprite: Sprite_Name, actor: ^Character, targets: []^Character, status_heals: []Status_Effect = {}) {
	skill_say(name)
	item_forward(actor^)

	results: [dynamic]Heal_Result; defer clear(&results)
	gains: [dynamic]int; defer clear(&gains)

	for target in targets {
		r: Heal_Result
		g: int
		if downed(target^) {
			append(&results, r)
			continue
		}
		r, g = try_heal(actor, target, heal_data)
		append(&results, r)
		append(&gains, g)
		play_sound(sound)
		run_anim(target.eid, sprite, flip_x = target.team == .Player)
	}

	for r, i in results {
		target := targets[i]
		target_eid := target.eid
		switch r {
		case .None:
		case .Miss:
			popup(target_eid, rl.GRAY, "Mi", dmg=true)
		case .Ineffective:
			popup(target_eid, rl.GRAY, "Ine", dmg=true)
		case .Effective:
			popup(target_eid, rl.GREEN, "%d", gains[i], dmg=true)
			restore_hitpoints(target, gains[i])
		}
	}

	walk_back(actor^)
}

@(private = "file")
skill_proc_remove_status_single_target_item :: proc(name: string, sts_acc: int, status: Status_Name, actor: ^Character, target: ^Character) {
	skill_say(name)
	target_eid := target.eid
	item_forward(actor^)
	play_sound(.Warp)
	run_anim(target_eid, .Heal)
	try_remove_status(target, sts_acc=sts_acc, status=.Poison)
	walk_back(actor^)
}

top_result :: proc(asi_result: ASI_Result) -> Hit_Result {
	if r := asi_result.attack_result;  r != .None do return r
	if r := asi_result.stagger_result; r != .None do return r
	return asi_result.interrupt_result
}

Status_Effect :: struct {
	acc:    int,
	status: Status_Name,
}

@(private = "file")
show_attack_results :: proc(target: ^Character, r: ASI_Result) {
	target_eid := target.eid
	switch top_result(r) {
	case .None:
	case .Miss:
		popup(target_eid, rl.GRAY, "Mi", dmg=true)
	case .Evade:
		popup(target_eid, rl.GRAY, "Eva", dmg=true)
	case .Resist:
		popup(target_eid, rl.GRAY, "Res", dmg=true)
	case .Hit:
	}
	if r.attack_result == .Hit do popup(target_eid, rl.WHITE, "%d", r.damage, dmg=true)
	// TODO: shudder animation for stagger hit
}

@(private = "file")
skill_proc_basic_attack_some :: proc(name: string, attack: Attack_Data, sound: Sound_Name, sprite: Sprite_Name, actor: ^Character, targets: []^Character, status_effects: []Status_Effect = {}) {
	skill_say(name)
	lunge_forward(actor^)

	results: [dynamic]ASI_Result; defer clear(&results)

	for target in targets {
		r: ASI_Result
		if downed(target^) {
			append(&results, r)
			continue
		}
		r = try_attack(actor^, target^, attack)
		append(&results, r)
		switch top_result(r) {
		case .None:
		case .Miss:
			// play_sound(.Whiff)
		case .Evade:
			// play_sound(.Whiff)
		case .Resist:
			// play_sound(.Ting)
		case .Hit:
			play_sound(sound)
		}
		run_anim(target.eid, sprite, flip_x = target.team == .Player)
	}

	for r, i in results {
		target := targets[i]
		if r.attack_result == .Hit do take_damage(target, r.damage)
		if r.stagger_result == .Hit do stagger_character(target, r.stagger)
		if r.interrupt_result == .Hit do interrupt_windup(target)
		show_attack_results(target, r)

		for status_effect in status_effects {
			try_add_status(actor, target, status_effect.acc, status_effect.status)
		}
	}

	walk_back(actor^)
}

@(private = "file")
skill_proc_add_status :: proc(name: string, status: Status_Name, sts_acc: int, sound: Sound_Name, sprite: Sprite_Name, actor: ^Character, targets: []^Character) {
	skill_say(name)
	item_forward(actor^)
	for target in targets {
		target_eid := target.eid
		play_sound(sound)
		run_anim(target_eid, sprite)
		try_add_status(actor, target, sts_acc=sts_acc, status=status)
	}
	walk_back(actor^)
}

// ********************
// ********************

@(private = "file")
PLAYER_DX :: 2 // distance players move horizontally in tiles

@(private = "file")
lunge_forward :: proc(actor: Character) {
	if !battle_active() do return
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
	if !battle_active() do return
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
	if !battle_active() do return
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

@(private = "file")
skill_say :: proc(name: string) {
	say(name, hurry=true, justify=.Center, lines=1, line_width=-1, pause=1)
}
