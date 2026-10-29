package game

import sa "core:container/small_array"
import "core:log"

import rl "vendor:raylib"

BATTLE_SPEED :: 2 // ticks per second per speed

TAKE_TURN_DELAY :: .5 // seconds

MULTI_TARGET_DELAY :: .2 // seconds

BATTLE_POPUP_TIME :: f32(1)
MAX_BATTLE_POPUPS :: 32

MAX_COMBATANTS :: MAX_ENCOUNTER_SIZE + NUM_PC

BADDY_ORIGIN  :: Tile{2, 3}
ALLY_ORIGIN   :: Tile{12, 3}

COMBATANT_LAYER  :: 0
SKILL_ANIM_LAYER :: 1 // skill animations draw over the combatants

Battle :: struct {
	active: bool, // battle will be drawn if true, else world
	allies:       [dynamic]int,
	baddies:      [dynamic]int,
	// background: Maybe(Battle_Background),
	camera:          Camera,
	combatants:   [dynamic]Combatant,
	encounter:    ^Encounter,
	paused:         bool, // true while running audiovisual stuff
	popups:         sa.Small_Array(MAX_BATTLE_POPUPS, Battle_Popup),
	result:         Maybe(Battle_Result), // set once a team has won and the last skill play has been shown
	results:        [dynamic]Battle_Effect_Result, // the skill play being shown; see process_skill_results
	results_script: Script_Id,
	skill_plays:  [dynamic]Battle_Skill_Play,
	skill_result: [dynamic]Battle_Effect_Result, // used for visualization; cleared after every tick
	ui_disabled:    bool, // don't draw the menu or accept input while true
}

battle: Battle

// Text that rises from a combatant and fades out, e.g. damage. See battle_popup.
Battle_Popup :: struct {
	using popup: Effect_Popup,
	pos:         [2]f32, // world pixels
	t:           f32, // seconds since it appeared
}

targeting_ease: f32

encounter_init :: proc(encounter_name: Encounter_Name) {
	battle_clear()
	add_combatants_for_encounter(encounter_name) // writes data and creates baddy Characters
	spawn_combatants(encounter_name) // spawns Entities
	battle.encounter = &encounters[encounter_name]
	battle_menu_start()
	battle.camera.zoom = 1
	battle.active = true
	battle.paused = true
	battle.ui_disabled = false
	log.info("battle is Active")
}

// call this before battles
battle_clear :: proc() {
	for c_idx in battle.baddies {
		// free new Characters created with new_baddy in start_encounter
		delete(battle.combatants[c_idx].skills)
		free(battle.combatants[c_idx].character)
	}
	for c in battle.combatants do destroy_entity(c.eid)
	clear(&battle.allies)
	clear(&battle.baddies)
	clear(&battle.combatants)
	battle.encounter = nil
	battle.result = nil
}

// call when we're ready to switch back to world
battle_deactivate :: proc() {
	clear(&battle.skill_plays)
	clear(&battle.skill_result)
	script_cancel(battle.results_script)
	clear(&battle.results)
	sa.clear(&battle.popups)
	battle_menu_end()
	battle.active = false
}

battle_destroy :: proc() {
	delete(battle.allies)
	delete(battle.baddies)
	delete(battle.combatants)
	delete(battle.skill_plays)
	delete(battle.skill_result)
	delete(battle.results)
	battle = {}
}

battle_active :: proc() -> bool {
	return battle.active
}

battle_done :: proc() -> bool {
	return !battle_active()
}

battle_result :: proc() -> Maybe(Battle_Result) {
	return battle.result
}

// One entity per combatant, so battle.combatants[c_idx] shows
// battle.combatants[c_idx]. start_encounter adds the baddies in
// formation order, then the party in PC order.
@(private = "file")
spawn_combatants :: proc(name: Encounter_Name) {
	log.infof("spawning combatants for encounter %v", name)
	spawn_combatant :: proc(name: string, tile: Tile, sprite: Sprite_State) -> Entity_Id {
		log.infof("spawning combatant %s at %v", name, tile)
		return spawn_entity(Entity{name = name, tile = tile, sprite = sprite, ghost = true, battle = true})
	}

	for spot, baddy_idx in encounters[name].baddies {
		baddy_id := spot.baddy_id
		if baddy_id == .None do continue
		sprite: Sprite_State
		s := baddy_templates[baddy_id].texture
		sprite = create_sprite_state(s, play = true, layer = COMBATANT_LAYER)
		tile := BADDY_ORIGIN + 2 * Tile{i32(spot.tile.x), i32(spot.tile.y)}
		battle.combatants[baddy_idx].eid = spawn_combatant(baddy_templates[baddy_id].name, tile, sprite)
	}

	dy: i32 = 2
	y0: i32 = 3
	x: i32 = 9
	y: i32 = y0
	party_idx := 0
	for pc_idx in 0 ..< NUM_PC {
		if !game_data.party_membership[pc_idx] do continue
		battle.combatants[battle.allies[party_idx]].eid = spawn_combatant(playable_characters[pc_idx].name, {x, y}, pc_battle_sprite(pc_idx, COMBATANT_LAYER))
		party_idx += 1
		x += 1
		if party_idx != 3 {
			y += dy
		} else {
			y = y0 + dy / 2
		}
	}
}

draw_battle :: proc() {
	// TODO: draw background
	rl.BeginMode2D(battle.camera)
	{
		draw_entities(battle = true)
		if !battle.ui_disabled do draw_battle_combatants()
		draw_debug_battle()
	}
	rl.EndMode2D()
	battle_menu_draw(battle.ui_disabled)
	draw_battle_popups()

	// debug
	// rl.DrawText(fmt.ctprint(battle_ui_state), 0, i32(7 * tile_size), 16, rl.BLACK)
	// rl.DrawText(fmt.ctprint(battle.state), 0, i32(7.5 * tile_size), 16, rl.BLACK)
}

@(private = "file")
draw_gauge :: proc(origin: [2]f32, v, full: f32, filled_color, empty_color, maxed_color: rl.Color) {
	roundness := f32(1)
	segments := i32(1)
	x, y := origin.x, origin.y
	w, h := f32(16), f32(4)
	if v < full {
		rl.DrawRectangleRounded({x, y, w, h}, roundness, segments, empty_color)
		rl.DrawRectangleRounded({x, y, w * v / full, h}, roundness, segments, filled_color)
	} else {
		rl.DrawRectangleRounded({x, y, w, h}, roundness, segments, maxed_color)
	}
	rl.DrawRectangleRoundedLinesEx({x, y, w, h}, roundness, segments, 1, rl.BLACK) // border
}

@(private = "file")
draw_battle_combatants :: proc() {
	for c, c_idx in battle.combatants {
		if combatant_downed(c) do continue
		tile := entity_tile(c.eid)

		if battle_menu.ui_state != .Idle {
			if c_idx == battle_menu.c_idx {
				draw_tile_indicator(tile, direction = Tile_Indicator_Direction.Down)
			}
		}
		if targeted(c_idx, c.team) {
			draw_tile_indicator(tile)
		}

		// Under the combatant's tile.
		gauge_origin := tile_to_pixel(tile) + {0, 1.05 * TILE_SIZE}
		draw_gauge(gauge_origin, c.ticks, READY_TICKS, rl.WHITE, rl.GRAY, rl.YELLOW)
		if skill_play_idx, ok := get_combatant_skill_play(c_idx).?; ok {
			gauge_origin += {0, 0.35 * TILE_SIZE}
			v := battle.skill_plays[skill_play_idx].windup
			draw_gauge(gauge_origin, v, READY_TICKS, rl.LIME, rl.GRAY, rl.GREEN)
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
		at := p.pos / TILE_SIZE
		draw_text_center(at.x, at.y - 0.5 * k, cstring(&p.text[0]), color)
	}
}

battle_time_tick :: proc(dt: f32) {
	TICK_TIME :: .5
	@(static) time_since_tick: f32
	time_since_tick += dt
	if time_since_tick >= TICK_TIME {
		time_since_tick -= TICK_TIME
		battle_tick()
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
	autobattle = v
}

// Shows what the last tick's skill play did, one script per target (see
// show_skill_result), MULTI_TARGET_DELAY apart. The battle pauses until they
// have all finished, then ends if a team has won.
process_skill_results :: proc() {
	if len(battle.skill_result) == 0 do return
	log.info("processing skill results")
	assert(!script_alive(battle.results_script), "a skill play is already being shown")
	clear(&battle.results)
	append(&battle.results, ..battle.skill_result[:])
	battle.paused = true
	log.infof("starting show_skill_results: len(battle.results) = %d", len(battle.results))
	battle.results_script = spawn(show_skill_results, name = "skill results")
}

@(private = "file")
show_skill_results :: proc(_: Entity_Id) {
	scripts: sa.Small_Array(MAX_COMBATANTS, Script_Id)
	for r, i in battle.results {
		if i > 0 && !pause(MULTI_TARGET_DELAY) do return
		sa.push(&scripts, spawn(show_skill_result, battle.combatants[r.target_idx].eid, name = "skill result"))
	}
	for s in sa.slice(&scripts) {
		if !wait_script(s) do return
	}
	battle_menu_set_stale(.Baddies)
	battle_menu_set_stale(.Party)
	if result, over := check_win().?; over {
		log.infof("battle result non-nil: %v", result)
		battle.result = result
		if result == .Win {
			battle.ui_disabled = true
			battle_menu.ui_state = .Idle
			for c_idx in battle.allies {
				c := battle.combatants[c_idx]
				if combatant_alive(c) {
					set_sprite_tag_of(c.eid, .Cheer)
					set_anim_when(c.eid, .Always)
					play_anim(c.eid)
				}
			}
			say("Victory!")
			party_get_experience(battle.encounter.exp) // blocks with say
			// get_spoils()
			fade_screen(1, .5)
			battle_deactivate() // stop drawing battle and draw world
			play_prev_music()
			fade_screen(0, .5)
		}
	} else {
		battle.paused = false
	}
}

// Shows the skill result for target `self`: the skill's animation over it, its
// reaction and the result's popups, then ally_down or baddy_down if it went
// down.
@(private = "file")
show_skill_result :: proc(target_id: Entity_Id) {
	effect_result, found := skill_result_for(target_id)
	if !found {
		log.errorf("show_skill_result called for target_id %v but no effect result found", target_id)
		return
	}
	r := effect_result.result
	c := battle.combatants[effect_result.target_idx]
	if combatant_downed(c) && !r.downed {
		log.warnf("effect result tried to down the already downed combatant %s (c_idx=%d)", c.name, effect_result.target_idx)
		return
	}

	// animate reaction with tag change
	prev_tag: Maybe(Sprite_Tag)
	if c.team == PLAYER_TEAM {
		if new_tag, ok := effect_reaction_tag(r).?; ok {
			prev_tag = set_sprite_tag_of(target_id, new_tag)
			play_anim(target_id)
		}
	}

	skill := skills[effect_result.skill_name]
	play_sound(skill.sound)
	if !play_skill_anim(target_id, skill.animation) do return

	// restore previous tag
	if c.team == PLAYER_TEAM {
		if t, ok := prev_tag.?; ok {
			set_sprite_tag_of(target_id, t)
		}
	}

	// ignore status changes on downed targets
	popups := effect_popups(r, status = !r.downed)
	for p, i in sa.slice(&popups) {
		if i > 0 && !pause(POPUP_GAP) do return // pause between popups
		battle_popup(target_id, p)
	}

	if r.downed {
		if c.team == PLAYER_TEAM {
			ally_down(target_id)
		} else {
			baddy_down(target_id)
		}
	}
}

@(private = "file")
skill_result_for :: proc(target: Entity_Id) -> (Battle_Effect_Result, bool) {
	for r in battle.results {
		if battle.combatants[r.target_idx].eid == target do return r, true
	}
	return {}, false
}

// Plays `sprite` once over `target`'s tile and waits for it to end.
@(private = "file")
play_skill_anim :: proc(target: Entity_Id, sprite: Sprite_Name) -> bool {
	s := create_sprite_state(sprite, play = true, layer = SKILL_ANIM_LAYER)
	fx := spawn_entity(Entity{name = "skill animation", tile = entity_tile(target), sprite = s, ghost = true, battle = true})
	defer destroy_entity(fx)
	return pause(max(animation_length(s), .25)) // a static sprite still shows a moment
}

@(private = "file")
effect_reaction_tag :: proc(r: Effect_Result) -> Maybe(Sprite_Tag) {
	if r.hit == .Miss do return nil
	if r.hit == .Evade do return .LArm
	if r.hp_change < 0 do return .Hit
	if r.hp_change > 0 || r.levels > 0 do return .Cheer
	if r.stagger || r.interrupted do return .Kneeled
	switch r.status_result {
	case .Added:                                  return .Kneeled
	case .Removed:                                return .Cheer
	case .Ineffective, .Resisted, .Remove_Missed:
	case .None:
	}
	return nil
}

ally_down :: proc(self: Entity_Id) {
	set_sprite_tag_of(self, .Kneeled)
	pause(.25)
	play_sound(.Down)
	set_sprite_tag_of(self, .Downed)
}

baddy_down :: proc(self: Entity_Id) {
	pause(.25)
	play_sound(.Down)
	set_tint(self, rl.RED)
	fade_to(self, 0, .5)
	set_visible(self, false)
	set_tint(self)
}

targeted :: proc(c_idx, team: int) -> bool {
	if battle_menu.ui_state == .Skill_Target || battle_menu.ui_state == .Item_Target {
		switch ts in battle_menu.targets {
		case Target_One_Baddy:
			return team == BADDY_TEAM && c_idx == battle.baddies[ts.i]
		case Target_One_Ally:
			return team == PLAYER_TEAM && c_idx == battle.allies[ts.i]
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
