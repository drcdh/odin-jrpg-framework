package game

import sa "core:container/small_array"
import "core:log"

import rl "vendor:raylib"

import "../rules"

BATTLE_SPEED :: 2 // ticks per second per speed

TAKE_TURN_DELAY :: .5 // seconds

MULTI_TARGET_DELAY :: .2 // seconds

REACTION_TIME :: 1 // seconds a target shows how an effect landed

BATTLE_POPUP_TIME :: f32(1)
MAX_BATTLE_POPUPS :: 32

MAX_COMBATANTS :: MAX_ENCOUNTER_SIZE + rules.NUM_PC

// The battle field in world tiles. The camera centers on BATTLE_CENTER;
// baddies stand in their encounter formation from BADDY_ORIGIN, the party in
// a column from ALLY_ORIGIN.
BATTLE_CENTER :: Tile{VIEW_TILES_W / 2, VIEW_TILES_H / 2}
BADDY_ORIGIN  :: Tile{2, 3}
ALLY_ORIGIN   :: Tile{12, 3}

COMBATANT_LAYER  :: 0
SKILL_ANIM_LAYER :: 1 // skill animations draw over the combatants

Battle :: struct {
	active:         bool, // true when in battle mode (and not world mode)
	// background: Maybe(Battle_Background),
	combatants:     [dynamic]Entity_Id, // one per rules.battle.combatants, same order
	paused:         bool, // true while running audiovisual stuff
	ui_disabled:    bool, // don't draw the menu or accept input while true
	results:        [dynamic]rules.Battle_Effect_Result, // the skill play being shown; see process_skill_results
	results_script: Script_Id,
	popups:         sa.Small_Array(MAX_BATTLE_POPUPS, Battle_Popup),
	result:         Maybe(rules.Battle_Result), // set once a team has won and the last skill play has been shown
}

// Text that rises from a combatant and fades out, e.g. damage. See battle_popup.
Battle_Popup :: struct {
	using popup: Effect_Popup,
	pos:         [2]f32, // world pixels
	t:           f32, // seconds since it appeared
}

battle: Battle

targeting_ease: f32

// How a target takes an effect, shown for REACTION_TIME: allies (tagged
// sprites) strike a pose, baddies (static sprites) change tint.
Reaction :: enum {
	None,
	Hurt,
	Helped,
	Missed,
}

@(rodata)
REACTION_POSES := [Reaction]Sprite_Tag {
	.None   = .Idle,
	.Hurt   = .Kneeled,
	.Helped = .Cheer,
	.Missed = .Walk,
}

@(rodata)
REACTION_TINTS := [Reaction]rl.Color {
	.None   = rl.WHITE,
	.Hurt   = rl.RED,
	.Helped = rl.GREEN,
	.Missed = rl.GRAY,
}

start_encounter :: proc(name: rules.Encounter_Name) {
	set_curtain(1)
	rules.start_encounter(name)
	spawn_combatants(name)
	camera_to_tile(BATTLE_CENTER)
	battle_init()
	battle.active = true
	battle.paused = true
	play_music(.Battle)
	spawn(proc(_: Entity_Id) {
		if !fade_screen(0, .5) do return
		if !pause(.5) do return
		battle.paused = false
	}, name = "battle start")
}

battle_cleanup :: proc() {
	script_cancel(battle.results_script)
	for id in battle.combatants do destroy_entity(id)
	rules.battle_cleanup()
	clear(&battle.combatants)
	clear(&battle.results)
	sa.clear(&battle.popups)
	battle.result = nil
	battle_menu_end()
}

battle_deactivate :: proc() {
	battle.active = false
	battle_cleanup()
}

battle_destroy :: proc() {
	rules.battle_destroy()
	delete(battle.combatants)
	delete(battle.results)
	battle = {}
}

battle_init :: proc() {
	// Skill animations start in scripts, which can't load sprites.
	for sprite in skill_sprites {
		if name, ok := sprite.?; ok do preload_sprite(name)
	}
	battle_menu_start()
}

// The winning team, once the battle is over and its last skill play has been shown.
battle_result :: proc() -> Maybe(rules.Battle_Result) {
	return battle.result
}

// One entity per combatant, so battle.combatants[c_idx] shows
// rules.battle.combatants[c_idx]. rules.start_encounter adds the baddies in
// formation order, then the party in PC order.
@(private = "file")
spawn_combatants :: proc(name: rules.Encounter_Name) {
	spawn_combatant :: proc(name: string, tile: Tile, sprite: Sprite_State) {
		append(&battle.combatants, spawn_entity(Entity{name = name, tile = tile, sprite = sprite, ghost = true}))
	}

	for spot in rules.encounters[name].baddies {
		baddy_id := spot.baddy_id.? or_continue
		sprite: Sprite_State
		if s, ok := baddy_sprites[baddy_id].?; ok {
			sprite = create_sprite_state(s, play = true, layer = COMBATANT_LAYER)
		} else {
			log.warnf("%v has no battle sprite", baddy_id)
		}
		tile := BADDY_ORIGIN + 2 * Tile{i32(spot.tile.x), i32(spot.tile.y)}
		spawn_combatant(rules.baddy_templates[baddy_id].name, tile, sprite)
	}
	row: i32
	for pc_idx in 0 ..< rules.NUM_PC {
		if !rules.game_data.party_membership[pc_idx] do continue
		// Stagger the column so neighbours' gauges don't cover each other.
		tile := ALLY_ORIGIN + {row % 2, row}
		spawn_combatant(rules.playable_characters[pc_idx].name, tile, pc_battle_sprite(pc_idx, COMBATANT_LAYER))
		row += 1
	}
	assert(len(battle.combatants) == len(rules.battle.combatants), "combatant entities out of step with rules.battle")
}

// Screen space: call after EndMode2D. The combatants are entities, drawn by draw_world.
draw_battle :: proc() {
	draw_battle_combatants()
	draw_battle_popups()
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
	w, h := f32(16 * ZOOM), f32(4 * ZOOM)
	if v < full {
		rl.DrawRectangleRounded({x, y, w, h}, roundness, segments, empty_color)
		rl.DrawRectangleRounded({x, y, w * v / full, h}, roundness, segments, filled_color)
	} else {
		rl.DrawRectangleRounded({x, y, w, h}, roundness, segments, maxed_color)
	}
	rl.DrawRectangleRoundedLinesEx({x, y, w, h}, roundness, segments, ZOOM, rl.BLACK) // border
}

@(private = "file")
draw_battle_combatants :: proc() {
	for id, c_idx in battle.combatants {
		c := rules.battle.combatants[c_idx]
		if rules.combatant_downed(c) do continue
		tile := entity_tile(id)

		if battle_menu.ui_state != .Idle {
			if c_idx == battle_menu.c_idx {
				draw_tile_indicator(tile, direction = Tile_Indicator_Direction.Down)
			}
		}
		if targeted(c_idx, c.team) {
			draw_tile_indicator(tile)
		}

		// Under the combatant's tile.
		gauge_origin := rl.GetWorldToScreen2D(tile_to_pixel(tile), world.camera) + {0, 1.05 * UI_TILE}
		draw_gauge(gauge_origin, c.ticks, rules.READY_TICKS, rl.WHITE, rl.GRAY, rl.YELLOW)
		if skill_play_idx, ok := rules.get_combatant_skill_play(c_idx).?; ok {
			gauge_origin += {0, 0.35 * UI_TILE}
			v := rules.battle.skill_plays[skill_play_idx].windup
			draw_gauge(gauge_origin, v, rules.READY_TICKS, rl.LIME, rl.GRAY, rl.GREEN)
		}
	}
}

// Shows `text` rising from the top of `id`'s tile.
battle_popup :: proc(id: Entity_Id, popup: Effect_Popup) {
	p := Battle_Popup{popup = popup, pos = entity_pos(id) - {0, TILE_SIZE / 2}}
	if !sa.push(&battle.popups, p) do log.warnf("Too many battle popups; dropped %q", cstring(&p.text[0]))
}

@(private = "file")
battle_popups_update :: proc(dt: f32) {
	for i := 0; i < sa.len(battle.popups); {
		p := sa.get_ptr(&battle.popups, i)
		p.t += dt
		if p.t >= BATTLE_POPUP_TIME {
			sa.ordered_remove(&battle.popups, i)
		} else {
			i += 1
		}
	}
}

@(private = "file")
draw_battle_popups :: proc() {
	for &p in sa.slice(&battle.popups) {
		k := p.t / BATTLE_POPUP_TIME
		color := p.color
		color.a = u8(255 * (1 - k))
		at := rl.GetWorldToScreen2D(p.pos, world.camera) / UI_TILE
		draw_text_center(at.x, at.y - 0.5 * k, cstring(&p.text[0]), color)
	}
}

battle_time_tick :: proc(dt: f32) {
	TICK_TIME :: .5
	@(static) time_since_tick: f32
	time_since_tick += dt
	if time_since_tick >= TICK_TIME {
		time_since_tick -= TICK_TIME
		rules.battle_tick()
		process_skill_results()
	}
}

update_battle :: proc(dt: f32) {
	if !battle.ui_disabled {
		battle_menu_update()
	}

	if !battle.paused && battle.result == nil {
		battle_time_tick(dt)
	}

	battle_popups_update(dt)

	targeting_ease += dt / .5
	if targeting_ease > 1 {targeting_ease = 0}
}

set_autobattle :: proc(v := true) {
	rules.autobattle = v
}

// Shows what the last tick's skill play did, one script per target (see
// show_skill_result), MULTI_TARGET_DELAY apart. The battle pauses until they
// have all finished, then ends if a team has won.
process_skill_results :: proc() {
	if len(rules.battle.skill_result) == 0 do return
	assert(!script_alive(battle.results_script), "a skill play is already being shown")
	clear(&battle.results)
	append(&battle.results, ..rules.battle.skill_result[:])
	battle.paused = true
	battle.results_script = spawn(show_skill_results, name = "skill results")
}

@(private = "file")
show_skill_results :: proc(_: Entity_Id) {
	scripts: sa.Small_Array(MAX_COMBATANTS, Script_Id)
	for r, i in battle.results {
		if i > 0 && !pause(MULTI_TARGET_DELAY) do return
		sa.push(&scripts, spawn(show_skill_result, battle.combatants[r.target_idx], name = "skill result"))
	}
	for s in sa.slice(&scripts) {
		if !wait_script(s) do return
	}
	if result, over := rules.check_win().?; over {
		battle.result = result
	} else {
		battle.paused = false
	}
}

// Shows the skill result for target `self`: the skill's animation over it, its
// reaction and the result's popups, then ally_down or baddy_down if it went
// down.
@(private = "file")
show_skill_result :: proc(self: Entity_Id) {
	br, found := skill_result_for(self)
	if !found do return
	r := br.result
	c := rules.battle.combatants[br.target_idx]
	if rules.combatant_downed(c) && !r.downed do return // already down: nothing to show

	if sound, ok := skill_sounds[br.skill_name].?; ok do play_sound(sound)
	if sprite, ok := skill_sprites[br.skill_name].?; ok {
		if !play_skill_anim(self, sprite) do return
	}

	react(self, c.team, effect_reaction(r))
	react_until := world.clock.time + REACTION_TIME

	// A downed target shows no status change.
	popups := effect_popups(r, status = !r.downed)
	for p, i in sa.slice(&popups) {
		if i > 0 && !pause(POPUP_GAP) do return
		battle_popup(self, p)
	}

	wait := f32(react_until - world.clock.time)
	if r.downed do wait = max(wait, BATTLE_POPUP_TIME) // let the damage popup finish
	if !pause(max(wait, 0)) do return
	react(self, c.team, .None)

	if r.downed {
		if c.team == PLAYER_TEAM {
			ally_down(self)
		} else {
			baddy_down(self)
		}
	}
}

@(private = "file")
skill_result_for :: proc(target: Entity_Id) -> (rules.Battle_Effect_Result, bool) {
	for r in battle.results {
		if battle.combatants[r.target_idx] == target do return r, true
	}
	return {}, false
}

// Plays `sprite` once over `target`'s tile and waits for it to end.
@(private = "file")
play_skill_anim :: proc(target: Entity_Id, sprite: Sprite_Name) -> bool {
	s := create_sprite_state(sprite, play = true, layer = SKILL_ANIM_LAYER)
	fx := spawn_entity(Entity{name = "skill animation", tile = entity_tile(target), sprite = s, ghost = true})
	defer destroy_entity(fx)
	return pause(max(animation_length(s), .25)) // a static sprite still shows a moment
}

@(private = "file")
effect_reaction :: proc(r: rules.Effect_Result) -> Reaction {
	if r.hit != .Hit do return .Missed
	if r.hp_change < 0 do return .Hurt
	if r.hp_change > 0 || r.levels > 0 do return .Helped
	switch r.status_result {
	case .Added:                                  return .Hurt
	case .Removed:                                return .Helped
	case .Ineffective, .Resisted, .Remove_Missed: return .Missed
	case .None:
	}
	return .None
}

// Shows `reaction` on `id`; .None restores its idle pose or tint.
@(private = "file")
react :: proc(id: Entity_Id, team: int, reaction: Reaction) {
	if team == PLAYER_TEAM {
		set_sprite_tag_of(id, REACTION_POSES[reaction])
		play_anim(id)
	} else {
		set_tint(id, REACTION_TINTS[reaction])
	}
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
