package game

import sa "core:container/small_array"
import "core:log"

import rl "vendor:raylib"

BATTLE_SPEED :: 30 // combatant ticks per second. TODO: player-configurable in System menu
BATTLE_TICK_TIME :: 0.1 // seconds per battle tick
SPEED_PAR :: 30

TAKE_TURN_DELAY :: .5 // seconds

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

// Battle_Proc :: proc(start := false, result: Maybe(Battle_Result) = nil) -> bool // return true to do default init/win/lose stuff
// Turn_Proc :: proc(actor_idx: int)

Battle_Result :: enum {
	None,
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
	new_downed: [dynamic]^Character,
	paused:         bool, // true while visualizing skill plays and results
	poison_ticks:   int, // battle ticks since poison last did damage
	result:         Battle_Result,
	// results:        [dynamic]Battle_Effect_Result, // the skill play being shown; see process_skill_results
	// results_actor:  int,
	// results_script: Script_Id,
	// results_skill:  Skill_Name,
	script:     Script_Id,
	skill_play: Battle_Skill_Play, // current, popped from queue
	skill_plays:    [dynamic]Battle_Skill_Play,
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

interrupt_skill_play :: proc(c: ^Character) {
	if i, ok := get_combatant_skill_play(c).(int); ok {
		log.infof("interrupting skill play %d", i)
		remove_skill_play(i)
	} else {
		log.warnf("%s does not have a queued skill play", c.name)
	}
}

remove_skill_play :: proc(i: int) {
  // remove from queue. Must be ordered so ties are broken correctly
	// this may be called when a skill play is executed or is interrupted
	log.infof("removing skill play %d: %v", i, battle.skill_plays[i])
	ordered_remove(&battle.skill_plays, i)
}

pause_battle :: proc(paused := true) {
	prev := battle.paused
	log.infof("battle paused %v (was %v)", paused, prev)
	battle.paused = paused
}

battle_tick :: proc() {
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

	for &s in battle.skill_plays {
		update_skill_play(&s)
	}

	for i := 0; i < len(battle.skill_plays); {
		if charge_full(battle.skill_plays[i].charge) {
			battle.skill_play = battle.skill_plays[i] // copy skill play
			remove_skill_play(i)
			battle.script = spawn(process_skill_play)
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
	// Don't reset character charge yet, since we don't know whether the skill play will complete or be interrupted
	// reset_character_charge(battle.combatants[actor_idx], Ticks(skill.cost))
	battle.combatants[actor_idx].windup = true
	update_character_sprite(battle.combatants[actor_idx]^)
	append(&battle.skill_plays, Battle_Skill_Play{actor_idx, targets, skill_name, new_charge(max=Ticks(skill.windup))})
}

// TODO: per-combatant poison timers and severity
battle_poison_tick :: proc() -> bool {
	return false
	// for &c, c_idx in battle.combatants {
	// 	if !alive(c^) || !has_status(c^, .Poison) do continue
	// 	hp_loss := take_poison_damage(c)
	// 	log.infof("%s takes %d damage from poison", c.name, hp_loss)
	// 	append(&battle.skill_result, Battle_Effect_Result{
	// 		source     = .Passive,
	// 		actor_idx  = -1,
	// 		target_idx = c_idx,
	// 		result     = {hp_change = -hp_loss, downed = c.hitpoints == 0},
	// 	})
	// }
	// return len(battle.skill_result) > 0
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
	battle.start_proc_run = false
	battle.poison_ticks = 0
	battle.ui_disabled = false
	battle.lose_proc = lose_proc
	battle.start_proc = start_proc
	battle.win_proc = win_proc
	pause_battle()
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
	clear(&battle.new_downed)
	battle.encounter = nil
	battle.result = nil
}

// call when we're ready to switch back to world
battle_deactivate :: proc() {
	clear(&battle.skill_plays)
	script_cancel(battle.script)
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
	delete(battle.new_downed)
	delete(battle.skill_plays)
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
		c_idx := battle.baddies[baddy_idx]
		battle.combatants[c_idx].eid = spawn_combatant(baddy_templates[baddy_id].name, tile, sprite)
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
		// visually update gauges
		// battle_menu_set_stale(.Party)
		battle_menu_set_stale(.Skills)
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

	check_downed_combatants()

	if !script_alive(battle.script) {
		switch check_win() {
		case .None:
		case .Lose:
			if battle.lose_proc != nil {
				log.info("LOSE - spawning special lose_proc")
				battle.script = spawn(battle.lose_proc)
			} else {
				log.info("LOSE - spawning default_lose_proc")
				battle.script = spawn(default_lose_proc)
			}
		case .Win:
			if battle.win_proc != nil {
				log.info("WIN - spawning special win_proc")
				battle.script = spawn(battle.win_proc)
			} else {
				log.info("WIN - spawning default_win_proc")
				battle.script = spawn(default_win_proc)
			}
		}
	}

	if !battle.paused && battle.result == nil {
		battle_time_tick(dt)
	}

	popups_update(dt)

	targeting_ease += dt / .5
	if targeting_ease > 1 {targeting_ease = 0}
}

queue_downed :: proc(c: ^Character) {
	if !battle_active() {
		log.infof("%s downed while battle not active", c.name)
		return
	}
	append(&battle.new_downed, c)
	log.infof("queued %s for down proc", c.name)
}

// Spawn and wait on animations for any characters downed in last battle tick
// TODO: reimplement special down procs; prioritize combatants with default
check_downed_combatants :: proc() {
	if len(battle.new_downed) == 0 do return
	battle.script = spawn(proc(_: Entity_Id) {
		pause_battle(); defer pause_battle(false)
		log.infof("downing %d combatants", len(battle.new_downed))
		scripts: sa.Small_Array(MAX_COMBATANTS, Script_Id)
		// for i := 0; i < sa.len(battle.downed_combatants); i += 1 {
		for c in battle.new_downed {
			sa.push(&scripts, spawn(baddy_down if c.team == .Baddy else player_down, c.eid))
		}
		clear(&battle.new_downed)
		for script in sa.slice(&scripts) {
			if !wait_script(script) do return
		}
	}, name = "down combatants")
}

set_autobattle :: proc(v := true) {
	autobattle = v
}

default_start_proc :: proc(_: Entity_Id) {
	play_music(.Battle)
	fade_screen(0, .25)
	pause(.25)
	pause_battle(false)
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
	battle.result = .Win
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
	battle.result = .Lose
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

baddy_down :: proc(self: Entity_Id) {
	log.infof("downing baddy eid=%v", self)
	pause(.25)
	play_sound(.Down)
	set_tint(self, rl.RED)
	fade_to(self, 0, .5)
	set_visible(self, false)
	set_tint(self)
}

player_down :: proc(self: Entity_Id) {
	log.infof("downing player eid=%v", self)
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
