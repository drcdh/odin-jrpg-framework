package game

import "core:fmt"
import "core:math"

import rl "vendor:raylib"

import "../rules"

BATTLE_SPEED :: 2 // ticks per second per speed

TAKE_TURN_DELAY :: .5 // seconds

MULTI_TARGET_DELAY :: .2 // seconds

Battle :: struct {
	active:     bool, // true when in battle mode (and not world mode)
	// background: Maybe(Battle_Background),
	combatants: [dynamic]Entity_Id,
	paused: bool, // true while running audiovisual stuff
	ui_disabled: bool, // don't draw the menu or accept input while true
}

battle: Battle

targeting_ease: f32

battle_cleanup :: proc() {
	rules.battle_cleanup()
	clear(&battle.combatants)
	battle_menu_end()
}

battle_deactivate :: proc() {
	battle.active = false
	battle_cleanup()
}

battle_destroy :: proc() {
	rules.battle_destroy()
	delete(battle.combatants)
}

battle_init :: proc() {
	battle_menu_start()
}

draw_battle :: proc() {
	// draw_battle_background(battle.background)
	draw_battle_combatants()
	battle_menu_draw()

	// debug
	// rl.DrawText(fmt.ctprint(battle_ui_state), 0, i32(7 * tile_size), 16, rl.BLACK)
	// rl.DrawText(fmt.ctprint(battle.state), 0, i32(7.5 * tile_size), 16, rl.BLACK)
}

@(private = "file")
draw_gauge :: proc(origin: [2]f32, v, full: f32, filled_color, empty_color, maxed_color: rl.Color) {
	roundness := f32(1)
	segments := i32(1)
	x, y := origin.x, origin.y
	w, h := 16, 4
	if v < full {
		rl.DrawRectangleRounded({x, y, w, h}, roundness, segments, empty_color)
		rl.DrawRectangleRounded({x, y, w * v / full, h}, roundness, segments, filled_color)
	} else {
		rl.DrawRectangleRounded({x, y, w, h}, roundness, segments, maxed_color)
	}
	rl.DrawRectangleRoundedLinesEx({x, y, w, h}, roundness, segments, zoom, rl.BLACK) // border
}

@(private = "file")
draw_battle_combatants :: proc() {
	for cv, c_idx in battle.combatants {
		c := rules.battle.combatants[c_idx]
		if true {//c.enabled {
			draw_sprite(cv) // FIXME

			if battle_menu.ui_state != .Idle {
				if c_idx == battle_menu.c_idx {
					draw_tile_indicator(c_coord, direction = Tile_Indicator_Direction.Down)
				}
			}
			if targeted(c_idx, c.team) {
				draw_tile_indicator(c_coord)
			}

			gauge_origin := c_coord + {0, 1.65 * tile_size}
			draw_gauge(gauge_origin, c.ticks, rules.READY_TICKS, rl.WHITE, rl.GRAY, rl.YELLOW)
			if skill_play_idx, ok := rules.get_combatant_skill_play(c_idx).?; ok {
				gauge_origin += {0, 0.35 * tile_size}
				v := rules.battle.skill_plays[skill_play_idx].windup
				draw_gauge(gauge_origin, v, rules.READY_TICKS, rl.LIME, rl.GRAY, rl.GREEN)
			}

			// debug
			// draw_text(
			// 	c.coord.x / tile_size,
			// 	c.coord.y / tile_size,
			// 	fmt.ctprintf("%.0f", abs(c.ticks)),
			// 	rl.WHITE if c.ticks >= 0 else rl.ORANGE,
			// )
			// if skill_play_idx, ok := get_combatant_skill_play(c_idx).?; ok {
			// 	draw_text(
			// 		c.coord.x / tile_size,
			// 		.5 + c.coord.y / tile_size,
			// 		fmt.ctprintf("%.0f", battle.skill_plays[skill_play_idx].windup),
			// 		rl.ORANGE,
			// 	)
			// }
		}
	}
}

battle_time_tick :: proc(dt: f32) {
	TICK_TIME :: .5
	@(static) time_since_tick: f32
	time_since_tick += dt
	if time_since_tick >= TICK_TIME {
		time_since_tick -= TICK_TIME
		rules.battle_tick()
		process_skill_results() // TODO: use rules.battle.skill_result to run audiovisual scripts for skill plays
	}
}

update_battle :: proc(dt: f32) {
	if !battle.ui_disabled {
		battle_menu_update()
	}

	if !battle.paused {
		battle_time_tick(dt)
	}

	targeting_ease += dt / .5
	if targeting_ease > 1 {targeting_ease = 0}

	for c in battle.combatants {
		update_sprite(dt, c) // FIXME
	}
}

set_autobattle :: proc(v := true) {
	rules.autobattle = v
}

ally_down :: proc(self: Entity_Id) {
	pause(.25)
	// play_sound(.Down)
	set_sprite_tag_of(self, .Downed)
}

baddy_down :: proc(self: Entity_Id) {
	pause(.25)
	// play_sound(.Down)
	set_tint(self, rl.RED)
	fade_to(self, 0, .5)
	set_visible(self, false)
	set_tint(self)
}

// play_anim_sounds :: proc(skill_play: Battle_Skill_Play, runner_idx: int) {
// 	play_anim_sound :: proc(
// 		sprite_name: Sprite_Name,
// 		sound: Sound_Name,
// 		runner_idx: int,
// 		target: ^Combatant,
// 		delay: f32 = 0,
// 	) -> f32 {
// 		// skill animation on an individual target
// 		r := center_animation_on_combatant(sprite_name, target^)
// 		queue_events(Play_Animation{delay, {r.x, r.y}, sprite_name}, Play_Sound{delay, sound}, i = runner_idx)
// 		return delay + animation_length(sprite_name)
// 	}
//
// 	skill := skill_play.skill
// 	wait_time: f32
//
// 	switch targets in skill_play.targets {
// 	case Target_One_Ally:
// 		target := battle.combatants[rules.battle.allies[targets.i]]
// 		wait_time = play_anim_sound(skill.animation, skill.sound, runner_idx, &target)
// 	case Target_One_Baddy:
// 		target := battle.combatants[rules.battle.baddies[targets.i]]
// 		wait_time = play_anim_sound(skill.animation, skill.sound, runner_idx, &target)
// 	case Target_All_Allies:
// 		for target_idx, i in rules.battle.allies {
// 			target := battle.combatants[target_idx]
// 			if target.enabled {
// 				wait_time = play_anim_sound(
// 					skill.animation,
// 					skill.sound,
// 					runner_idx,
// 					&target,
// 					delay = f32(i) * MULTI_TARGET_DELAY,
// 				)
// 			}
// 		}
// 	case Target_All_Baddies:
// 		for target_idx, i in rules.battle.baddies {
// 			target := battle.combatants[target_idx]
// 			if battle.combatants[target_idx].enabled {
// 				wait_time = play_anim_sound(
// 					skill.animation,
// 					skill.sound,
// 					runner_idx,
// 					&target,
// 					delay = f32(i) * MULTI_TARGET_DELAY,
// 				)
// 			}
// 		}
// 	case Target_All_Combatants:
// 		for &target, target_idx in battle.combatants {
// 			if target.enabled {
// 				wait_time = play_anim_sound(
// 					skill.animation,
// 					skill.sound,
// 					runner_idx,
// 					&target,
// 					delay = f32(target_idx) * MULTI_TARGET_DELAY,
// 				)
// 			}
// 		}
// 	}
//
// 	// wait for animations to complete
// 	queue_events(Pause_Runner{wait_time}, i = runner_idx)
// }

targeted :: proc(c_idx, team: int) -> bool {
	if battle_menu.ui_state == .Skill_Target || battle_menu.ui_state == .Item_Target {
		switch ts in battle_menu.targets {
		case Target_One_Baddy:
			return team == BADDY_TEAM && c_idx == rules.battle.baddies[ts.i]
		case Target_One_Ally:
			return team == PLAYER_TEAM && c_idx == rules.battle.allies[ts.i]
		case Target_All_Allies:
			return team == PLAYER_TEAM
		case Target_All_Baddies:
			return team == BADDY_TEAM
		case Target_All_Combatants:
			return true
		}
	}
	return false
}
