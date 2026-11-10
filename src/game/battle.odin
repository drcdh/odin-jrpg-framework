package game

import sa "core:container/small_array"
import "core:fmt"
import "core:log"

import rl "vendor:raylib"

BATTLE_SPEED :: 30 // combatant ticks per second. TODO: player-configurable in System menu
BATTLE_TICK_TIME :: 0.1 // seconds per battle tick
SPEED_PAR :: 30

TAKE_TURN_DELAY :: .5 // seconds

MULTI_TARGET_DELAY :: .2 // seconds

POISON_PERIOD :: 5 // seconds of battle time between poison damage

BATTLE_POPUP_TIME :: f32(1)
MAX_BATTLE_POPUPS :: 32

MAX_COMBATANTS :: MAX_ENCOUNTER_SIZE + NUM_PC

BADDY_ORIGIN  :: Tile{2, 3}
PARTY_ORIGIN   :: Tile{12, 3}

COMBATANT_LAYER  :: 0
SKILL_ANIM_LAYER :: 1 // skill animations draw over the combatants

Team :: enum { None, Baddy, Player }

Ticks :: f32

Battle_Skill_Play :: struct {
	actor_idx:  int,
	targets:    Target_Selection,
	skill_name: Skill_Name,
	charge:     Charge,
}

// Where an effect result came from. Passive effects (poison, and later other
// periodic effects) have no actor and are shown without skill banners or animations.
Battle_Effect_Source :: enum {
	Skill,
	Passive,
}

// What a skill play or passive effect did to one target
Battle_Effect_Result :: struct {
	source:     Battle_Effect_Source,
	actor_idx:  int,        // ignored unless source == .Skill
	target_idx: int,
	skill_name: Skill_Name, // ignored unless source == .Skill
	result:     Effect_Result,
}

// Battle_Proc :: proc(start := false, result: Maybe(Battle_Result) = nil) -> bool // return true to do default init/win/lose stuff
// Turn_Proc :: proc(actor_idx: int)

Battle_Result :: enum {
	Lose,
	Win,
}

Battle :: struct {
	active:					bool, // battle will be drawn if true, else world
	baddies:      	[dynamic]int,
	players:        [dynamic]int,
	background:			Battle_Background,
	camera:         Camera,
	combatants:			[dynamic]^Character,
	encounter:    	^Encounter,
	lose_proc:      Script_Proc,
	paused:         bool, // true while running audiovisual stuff
	poison_ticks:   int, // battle ticks since poison last did damage
	result:         Maybe(Battle_Result), // set once a team has won and the last skill play has been shown
	// results:        [dynamic]Battle_Effect_Result, // the skill play being shown; see process_skill_results
	// results_actor:  int,
	// results_script: Script_Id,
	// results_skill:  Skill_Name,
	skill_play: Battle_Skill_Play, // current, popped from queue
	skill_play_queue:    [dynamic]Battle_Skill_Play,
	skill_play_script: Script_Id,
	// skill_result:   [dynamic]Battle_Effect_Result, // used for visualization; cleared after every tick
	start_proc:     Script_Proc,
	start_proc_run: bool,
	ui_disabled:    bool, // don't draw the menu or accept input while true
	win_proc:       Script_Proc,
}

battle: Battle

targeting_ease: f32
autobattle: bool // debug mode

check_win :: proc() -> Maybe(Battle_Result) {
	players_alive := false
	for c_idx in battle.players {
		if alive(battle.combatants[c_idx]^) {
			players_alive = true
		}}
	if !players_alive {
		return .Lose
	}
	baddies_alive := false
	for c_idx in battle.baddies {
		if alive(battle.combatants[c_idx]^) {
			baddies_alive = true
		}
	}
	if !baddies_alive {
		return .Win
	}
	return nil
}

ready :: proc(c: Character) -> bool {
	return charge_full(c.charge) && alive(c) && !winding_up(c)
}

winding_up :: proc(c: Character) -> bool {
	return c.windup
}

get_combatant_skill_play_idx :: proc(c_idx: int) -> Maybe(int) {
	for sp, i in battle.skill_plays {
		if sp.actor_idx == c_idx {
			return i
		}
	}
	return nil
}

get_combatant_skill_play_ptr :: proc(c: ^Character) -> Maybe(int) {
	for sp, i in battle.skill_plays {
		if battle.combatants[sp.actor_idx] == c {
			return i
		}
	}
	return nil
}

get_combatant_skill_play :: proc {
	get_combatant_skill_play_idx,
	get_combatant_skill_play_ptr,
}

battle_tick :: proc() {
	// clear(&battle.skill_result)

	// Poison gets a tick to itself so its results are never shown with a skill play's.
	// TODO: Character statuses will have data for status-specific procedures (e.g. poison dmg, paralysis or sleep wearing off)
	battle.poison_ticks += 1
	if f32(battle.poison_ticks) * BATTLE_TICK_TIME >= POISON_PERIOD {
		battle.poison_ticks = 0
		if battle_poison_tick() do return
	}

	take_turns()

	for c in battle.combatants {
		character_battle_tick(c)
	}

	// remove invalid Skill_Plays
	// TODO: do this when a character is interrupted or downed in the specific procedure
	for i := 0; i < len(battle.skill_plays); {
		c := battle.combatants[battle.skill_plays[i].actor_idx]
		if !winding_up(c^) || !alive(c^) {
			fmt.printfln("removing Battle_Skill_Play %d after combatant interrupted or downed", i)
			unordered_remove(&battle.skill_plays, i)
		} else {
			i += 1
		}
	}

	for &s in battle.skill_plays {
		update_skill_play(&s)
	}

	for i := 0; i < len(battle.skill_plays); {
		if charge_full(battle.skill_plays[i].charge) {
			battle.skill_play = battle.skill_plays[i] // copy skill play
			unordered_remove(&battle.skill_plays, i) // remove from queue
			battle.skill_play_script = spawn(proc(_: Entity_Id) { process_skill_play_2() } )
			break
		} else {
			i += 1
		}
	}
}

update_skill_play :: proc(s: ^Battle_Skill_Play) {
	c := battle.combatants[s.actor_idx]
	ticks := (BATTLE_SPEED*BATTLE_TICK_TIME) * f32(get_stat(c^, .Speed))/SPEED_PAR
	update_charge(&s.charge, migraine_sprain_modify_charge(ticks, s.skill_name, has_status(c^, .Migraine), has_status(c^, .Sprain)))
}

player_controllable :: proc(c: Character) -> bool {
	if !ready(c) do return false
	if is_uncontrollable(c) do return false
	if c.team == .Player do return !has_status(c, .Control)
	return has_status(c, .Control)
}

get_next_player_controlled_combatant :: proc(previous: int) -> Maybe(int) {
	first: Maybe(int)
	met_previous: bool // loop passed `previous`
	for c, c_idx in battle.combatants {
		if player_controllable(c^) {
			if met_previous do return c_idx
			first = first.? or_else c_idx
		}
		if c_idx == previous do met_previous = true
	}
	return first
}

take_turns :: proc() {
	for c, c_idx in battle.combatants {
		if ready(c^) {
			assert(can_take_turn(c^), "combatant is ready but has invalidating status")
			if is_uncontrollable(c^) || autobattle { take_turn(c_idx); continue }
			if (c.team == .Baddy && has_status(c^, .Control)) || (c.team == .Player && !has_status(c^, .Control)) {
				if battle_menu.ui_state == .Idle do battle_menu_select_combatant(c_idx)
				continue
			}
			take_turn(c_idx) // baddy that's not controlled and can take turn
		}
	}
}

queue_battle_skill :: proc(actor_idx: int, targets: Target_Selection, skill_name: Skill_Name) {
	skill := skills[skill_name]
	reset_character_charge(battle.combatants[actor_idx], Ticks(skill.cost))
	battle.combatants[actor_idx].windup = true
	update_character_sprite(battle.combatants[actor_idx]^)
	append(&battle.skill_plays, Battle_Skill_Play{actor_idx, targets, skill_name, new_charge(max=Ticks(skill.windup))})
}

process_skill_play :: proc(skill_play: Battle_Skill_Play) {
	fmt.printfln("Processing skill play: %#v", skill_play)

	skill := skills[skill_play.skill_name]
	actor := battle.combatants[skill_play.actor_idx]
	actor.windup = false

	battle.results_actor = skill_play.actor_idx
	battle.results_skill = skill_play.skill_name

	affect :: proc(skill_play: Battle_Skill_Play, actor: ^Character, target_idx: int, skill: Skill) {
		r := do_skill(actor, battle.combatants[target_idx], skill)
		append(&battle.skill_result, Battle_Effect_Result{
			source     = .Skill,
			actor_idx  = skill_play.actor_idx,
			target_idx = target_idx,
			skill_name = skill_play.skill_name,
			result     = r,
		})
	}

	switch targets in skill_play.targets {
	case Target_One_Player:
		affect(skill_play, actor, battle.players[targets.i], skill)
	case Target_One_Baddy:
		affect(skill_play, actor, battle.baddies[targets.i], skill)
	case Target_All_Players:
		for target_idx in battle.players do affect(skill_play, actor, target_idx, skill)
	case Target_All_Baddies:
		for target_idx in battle.baddies do affect(skill_play, actor, target_idx, skill)
	case Target_All:
		for _, target_idx in battle.combatants do affect(skill_play, actor, target_idx, skill)
	}
}

// TODO: per-combatant poison timers and severity
battle_poison_tick :: proc() -> bool {
	for &c, c_idx in battle.combatants {
		if !alive(c^) || !has_status(c^, .Poison) do continue
		hp_loss := take_poison_damage(c)
		log.infof("%s takes %d damage from poison", c.name, hp_loss)
		append(&battle.skill_result, Battle_Effect_Result{
			source     = .Passive,
			actor_idx  = -1,
			target_idx = c_idx,
			result     = {hp_change = -hp_loss, downed = c.hitpoints == 0},
		})
	}
	return len(battle.skill_result) > 0
}

// Breaks `target`'s windup. Returns false if they weren't winding up.
interrupt_windup :: proc(target: ^Character) -> bool {
	if !target.windup {
		log.infof("Tried to interrupt %s but they weren't winding up", target.name)
		return false
	}
	target.windup = false
	update_character_sprite(target^)
	log.infof("Break! %s is interrupted", target.name)
	return true
}

roll_for_counter :: proc(actor, target: ^Character, risk: f32 = 1) {
}

encounter_init :: proc(encounter_name: Encounter_Name, start_proc, win_proc, lose_proc: Script_Proc) {
	battle_clear()
	add_combatants_for_encounter(encounter_name) // writes data and creates baddy Characters
	spawn_combatants(encounter_name) // spawns Entities
	battle.encounter = &encounters[encounter_name]
	battle.background = world.level_map.background
	battle_menu_start()
	battle.camera.zoom = 1
	battle.active = true
	battle.paused = true
	battle.start_proc_run = false
	battle.poison_ticks = 0
	battle.ui_disabled = false
	battle.lose_proc = lose_proc
	battle.start_proc = start_proc
	battle.win_proc = win_proc
	log.info("battle is Active")
}

// call this before battles
battle_clear :: proc() {
	for c_idx in battle.baddies {
		// free new Characters created with new_baddy in start_encounter
		delete(battle.combatants[c_idx].skills)
		destroy_entity(battle.combatants[c_idx].eid)
		free(battle.combatants[c_idx])
	}
	// the players' entities persist; battle_deactivate hid them
	clear(&battle.players)
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
	clear_popups()
	battle_menu_end()
	for c_idx in battle.players {
		c := battle.combatants[c_idx]
		set_visible(c.eid, false)
		update_character_sprite(c^) // undo battle poses like Cheer
	}
	battle.active = false
}

battle_destroy :: proc() {
	battle_clear()
	delete(battle.players)
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
		eid := pc_entity(pc_idx) // sets the PC's eid
		set_tile(eid, {x, y})
		set_visible(eid, true)
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
	draw_bb(battle.background)
	rl.BeginMode2D(battle.camera)
	{
		draw_entities(battle = true)
		if !battle.ui_disabled do draw_battle_combatants()
		draw_debug_battle()
	}
	rl.EndMode2D()
	battle_menu_draw(battle.ui_disabled)
	draw_popups()

	// debug
	// rl.DrawText(fmt.ctprint(battle_ui_state), 0, i32(7 * tile_size), 16, rl.BLACK)
	// rl.DrawText(fmt.ctprint(battle.state), 0, i32(7.5 * tile_size), 16, rl.BLACK)
}

@(private = "file")
draw_battle_combatants :: proc() {
	for c, c_idx in battle.combatants {
		if downed(c^) do continue
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
		if c.windup {
			if skill_play_idx, ok := get_combatant_skill_play(c_idx).?; ok {
				skill_play := battle.skill_plays[skill_play_idx]
				gauge_origin += {0, 0.35 * TILE_SIZE}
				gauge_tint := rl.WHITE
				// Migraine and Sprain affect windup
				if has_status(c^, .Migraine) && is_psychic_skill(skill_play.skill_name) do gauge_tint = rl.ColorTint(gauge_tint, rl.BLUE)
				if has_status(c^, .Sprain) && is_physical_skill(skill_play.skill_name) do gauge_tint = rl.ColorTint(gauge_tint, rl.ORANGE)
				draw_charge(
					gauge_origin,
					skill_play.charge,
					gauge_tint,
					rl.PINK,
					rl.GRAY,
					rl.GREEN,
				)
			}
		} else {
			draw_charge(
				gauge_origin,
				c.charge,
				rl.BLUE if has_status(c^, .Slow) else rl.WHITE,
				rl.PINK,
				rl.GRAY,
				rl.YELLOW,
			)
		}
	}
}

battle_time_tick :: proc(dt: f32) {
	@(static) time_since_tick: f32
	time_since_tick += dt
	if time_since_tick >= BATTLE_TICK_TIME {
		time_since_tick -= BATTLE_TICK_TIME
		battle_tick()
		// process_skill_results()
		// visually update gauges
		// battle_menu_set_stale(.Party)
		// battle_menu_set_stale(.Skills)
	}
}

update_battle :: proc(dt: f32) {
	if !battle.start_proc_run {
		if battle.start_proc != nil {
			spawn(battle.start_proc)
		} else {
			spawn(default_start_proc)
		}
		battle.start_proc_run = true
	}

	if !battle.ui_disabled {
		battle_menu_update()
	}

	if !battle.paused && battle.result == nil {
		battle_time_tick(dt)
	}

	popups_update(dt)

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
	ATTACK_TIME :: .25 // time to animate approach and retreat
	PARTY_DX :: 2 // distance players move horizontally in tiles

	// passive effects (e.g. poison) have no actor, text, or animations
	is_skill := battle.results[0].source == .Skill

	actor: ^Character
	actor_eid: Entity_Id

	if is_skill {
		say(skills[battle.results_skill].name, hurry=true, justify=.Center, lines=1, line_width=-1, pause=1.5)

		actor = battle.combatants[battle.results_actor]
		actor_eid = actor.eid
		if actor.team == .Baddy {
			move_entity(actor_eid, {1, 0}, ATTACK_TIME)
		} else {
			set_sprite_tag_of(actor_eid, .RArm)
			freeze_anim(actor_eid, 1)
			wait_all(tween_jump(actor_eid, -PARTY_DX, 1, ATTACK_TIME))
			set_sprite_tag_of(actor_eid, .Walk)
			freeze_anim(actor_eid, 1)
		}
	}

	scripts: sa.Small_Array(MAX_COMBATANTS, Script_Id)
	for r, i in battle.results {
		if i > 0 && !pause(MULTI_TARGET_DELAY) do return
		sa.push(&scripts, spawn(show_skill_result, battle.combatants[r.target_idx].eid, name = "skill result"))
	}
	for s in sa.slice(&scripts) {
		if !wait_script(s) do return
	}

	if is_skill {
		if actor.team == .Baddy {
			move_entity(actor_eid, {-1, 0}, ATTACK_TIME)
		} else {
			set_sprite_tag_of(actor_eid, .Walk)
			play_anim(actor_eid)
			move_entity(actor_eid, {PARTY_DX, 0}, ATTACK_TIME)
			update_character_sprite(actor^)
		}
	}

	battle_menu_check_selection_valid()

	battle_menu_set_stale(.Baddies)
	battle_menu_set_stale(.Party)
	if result, over := check_win().?; over {
		log.infof("battle result non-nil: %v", result)
		battle.result = result
		if result == .Win {
			if battle.win_proc != nil {
				spawn(battle.win_proc)
			} else {
				spawn(default_win_proc)
			}
		} else if result == .Lose {
			if battle.lose_proc != nil {
				spawn(battle.lose_proc)
			} else {
				spawn(default_lose_proc)
			}
		}
	} else {
		battle.paused = false
	}
}

default_start_proc :: proc(_: Entity_Id) {
	play_music(.Battle)
	fade_screen(0, .25)
	pause(.25)
	battle.paused = false
}

default_win_proc :: proc(_: Entity_Id) {
	battle.ui_disabled = true
	battle_menu.ui_state = .Idle
	for c_idx in battle.players {
		c := battle.combatants[c_idx]
		if alive(c^) {
			set_sprite_tag_of(c.eid, .Cheer)
			set_anim_when(c.eid, .Always)
			play_anim(c.eid)
		}
	}
	say("Victory!", hurry=true, justify=.Center, lines=1, line_width=-1, pause=1.5)
	party_get_experience(battle.encounter.exp) // blocks with say
	// get_spoils()
	fade_screen(1, .5)
	battle_deactivate() // stop drawing battle and draw world
	play_prev_music()
	fade_screen(0, .5)
}

default_lose_proc :: proc(_: Entity_Id) {
	battle.ui_disabled = true
	battle_menu.ui_state = .Idle
	music_fade_down()
	say("Defeat|", hurry=true, justify=.Center, lines=1, line_width=-1, pause=1.5)
	fade_screen(1, .5)
	battle_deactivate() // stop drawing battle and draw world
	game_over()
}

continue_lose_proc :: proc(_: Entity_Id) {
	battle.ui_disabled = true
	battle_menu.ui_state = .Idle
	music_fade_down()
	say("Defeat|", hurry=true, justify=.Center, lines=1, line_width=-1, pause=1.5)
	fade_screen(1, .5)
	play_prev_music()
	music_fade_up()
	battle_deactivate()
	fade_screen(0, .5)
}

@(private = "file")
show_skill_result :: proc(target_id: Entity_Id) {
	effect_result, found := skill_result_for(target_id)
	if !found {
		log.errorf("show_skill_result called for target_id %v but no effect result found", target_id)
		return
	}
	r := effect_result.result
	c := battle.combatants[effect_result.target_idx]
	if downed(c^) && !r.downed {
		log.warnf("effect result tried to down the already downed combatant %s (c_idx=%d)", c.name, effect_result.target_idx)
		return
	}

	if effect_result.source == .Skill {
		if c.team == .Player {
			if new_tag, ok := effect_reaction_tag(r).?; ok {
				set_sprite_tag_of(target_id, new_tag)
				play_anim(target_id)
			}
		}

		skill := skills[effect_result.skill_name]
		play_sound(skill.sound)
		if !play_skill_anim(target_id, skill.animation) do return
	}

	// the new look (statuses, health) replaces the reaction pose; a downed
	// target's look comes from player_down or baddy_down instead
	if !r.downed do update_character_sprite(c^)

	if n := show_effect_popups(c^, r); n > 1 {
		if !pause(POPUP_GAP * f32(n - 1)) do return
	}

	if r.downed {
		if c.team == .Player {
			player_down(target_id)
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
play_skill_anim :: proc(target: Entity_Id, sprite: Sprite_Name, flip_x := false) -> bool {
	s := create_sprite_state(sprite, play = true, layer = SKILL_ANIM_LAYER, flip_x = flip_x)
	fx := spawn_entity(Entity{name = "skill animation", sprite = s, ghost = true, battle = true})
	if e, ok := entity_get(fx); ok do e.pos = entity_pos(target) // over the target, wherever it's drawn
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

baddy_down :: proc(self: Entity_Id) {
	pause(.25)
	play_sound(.Down)
	set_tint(self, rl.RED)
	fade_to(self, 0, .5)
	set_visible(self, false)
	set_tint(self)
}

player_down :: proc(self: Entity_Id) {
	set_sprite_tag_of(self, .Kneeled)
	pause(.25)
	play_sound(.Down)
	set_sprite_tag_of(self, .Downed)
}

targeted :: proc(c_idx: int, team: Team) -> bool {
	if battle_menu.ui_state == .Skill_Target || battle_menu.ui_state == .Item_Target {
		switch ts in battle_menu.targets {
		case Target_One_Baddy:
			return team == .Baddy && c_idx == battle.baddies[ts.i]
		case Target_One_Player:
			return team == .Player && c_idx == battle.players[ts.i]
		case Target_All_Players:
			return team == .Player
		case Target_All_Baddies:
			return team == .Baddy
		case Target_All:
			return true
		}
	}
	return false
}

opposite_team :: proc(team: Team) -> Team {
	if team == .Player do return .Baddy
	if team == .Baddy do return .Player
	return .None
}
