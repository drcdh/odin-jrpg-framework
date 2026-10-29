package game

import hm "core:container/handle_map"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// Debug aids. F1 toggles the overlay (draw_debug_world, draw_debug_hud; the
// key is read in player.odin). debug_update reads the other debug keys, from
// the old game, and debug_draw draws what they toggle; both do nothing
// outside debug builds (ODIN_DEBUG).

DEBUG_FRAMERATE_PERIOD :: 5 // seconds
THROTTLED_FPS :: #config(FPS, 60)

debug_framerate: bool
debug_framerate_count: int
debug_framerate_sum: f32

debug_grid: bool
debug_overlay: bool
debug_text: bool

// TODO: battle-only flags, unused until battles are ported.
force_drops: bool
moogle_charm: bool

throttle := true // vsync and SetTargetFPS(THROTTLED_FPS), as main sets up

// World space (inside BeginMode2D): grid lines, trigger outlines, and the tile the player faces.
draw_debug_world :: proc() {
	if !debug_overlay do return

	view := visible_world_rect()
	x0 := math.floor(view.x / TILE_SIZE) * TILE_SIZE
	y0 := math.floor(view.y / TILE_SIZE) * TILE_SIZE
	x1, y1 := view.x + view.width, view.y + view.height
	grid := rl.Color{255, 255, 255, 30}
	for x := x0; x <= x1; x += TILE_SIZE do rl.DrawLineV({x, y0}, {x, y1}, grid)
	for y := y0; y <= y1; y += TILE_SIZE do rl.DrawLineV({x0, y}, {x1, y}, grid)

	it := hm.iterator_make(&game.entities)
	for e, _ in hm.iterate(&it) {
		if e.trigger.script == nil do continue
		color := rl.GREEN if script_alive(e.trigger.running) else rl.GRAY
		rl.DrawRectangleLinesEx(tile_rect(e.tile), 1, color)
	}

	if p, ok := entity_get(game.world.player); ok {
		rl.DrawRectangleRec(tile_rect(p.tile + dir_vec(p.facing)), {255, 255, 0, 60})
	}
}

// Screen space (after EndMode2D): counters, the player's tile, and each live script's wait.
draw_debug_world_hud :: proc() {
	if !debug_overlay do return

	FONT :: 16
	x, y: i32 = 10, 10
	line :: proc(x: i32, y: ^i32, text: cstring, color := rl.RAYWHITE) {
		rl.DrawText(text, x, y^, FONT, color)
		y^ += FONT + 2
	}
	line(x, &y, fmt.ctprintf("fps %d   time %.2f   frame %d", rl.GetFPS(), game.clock.time, game.clock.frame))
	line(x, &y, fmt.ctprintf("entities %d   tweens %d   scripts %d",
		hm.len(game.entities), hm.len(game.tweens), len(game.script_order)))
	if p, ok := entity_get(game.world.player); ok {
		line(x, &y, fmt.ctprintf("player tile %v   facing %v", p.tile, p.facing))
	}
	for h in game.script_order {
		s, ok := hm.get(&game.scripts, h)
		if !ok do continue
		name := s.name if s.name != "" else "<unnamed>"
		color := rl.ORANGE if s.cancel_requested else rl.LIGHTGRAY
		line(x + 10, &y, fmt.ctprintf("%s [%d:%d]  %s", name, h.idx, h.gen, wait_describe(s.wait)), color)
	}
}

draw_debug_battle :: proc() {
	if !debug_overlay do return

	for c in game.battle.combatants {
		e := hm.get(&game.entities, c.eid)
		rl.DrawRectangleLinesEx(tile_rect(e.tile), 1, rl.GREEN)
	}
}

@(private)
tile_rect :: proc(t: Tile) -> rl.Rectangle {
	return {f32(t.x) * TILE_SIZE, f32(t.y) * TILE_SIZE, TILE_SIZE, TILE_SIZE}
}

@(private)
wait_describe :: proc(w: Wait) -> string {
	switch v in w {
	case Wait_Time:   return fmt.tprintf("pause, %.2fs left", max(v.until - game.clock.time, 0))
	case Wait_Frame:  return "next frame"
	case Wait_Tween:  return fmt.tprintf("tween [%d:%d]", v.tween.idx, v.tween.gen)
	case Wait_Script: return fmt.tprintf("script [%d:%d]", v.script.idx, v.script.gen)
	case Wait_Pred:   return "predicate"
	}
	return "starting"
}

// Screen space, after the HUD: the framerate bar (F), a UI-tile grid
// labelled in hex (G) and the font at three sizes (T).
debug_draw :: proc() {
	when !ODIN_DEBUG do return // debug builds only

	view := [2]f32{WINDOW_WIDTH, WINDOW_HEIGHT}
	font := game.ui.font

	if debug_framerate {
		h: f32 = 8
		origin := [2]f32{0, view.y - h}
		rl.DrawRectangleV(origin, {view.x, h}, rl.BLACK)
		mean: f32 = 0
		if debug_framerate_sum > 0 {
			mean = f32(debug_framerate_count) / debug_framerate_sum
		}
		rl.DrawTextEx(
			font,
			fmt.ctprintf("%.1f sec | %d frames | %.1f fps", debug_framerate_sum, debug_framerate_count, mean),
			origin,
			h,
			0,
			rl.WHITE,
		)
	}

	if debug_grid {
		c := rl.Color{100, 50, 50, 200}
		dg := i32(TILE_SIZE)
		G := i32(view.x)
		t := 0
		for g: i32 = 0; g <= G; g += dg {
			x := i32(view.x)
			y := i32(view.y)
			rl.DrawLine(g, 0, g, y, c)
			rl.DrawLine(0, g, x, g, c)
			rl.DrawTextEx(font, fmt.ctprintf("%X", t), {0, f32(g)}, TILE_SIZE, 0, c)
			rl.DrawTextEx(font, fmt.ctprintf("%X", t), {f32(g), 0}, TILE_SIZE, 0, c)
			t += 1
		}
	}

	if debug_text {
		h0 :: TILE_SIZE
		h : f32 = h0
		rl.DrawLineV({0, h0}, {view.x, h0}, rl.WHITE)
		rl.DrawTextEx(font, LETTERS_IN_FONT, {0, 0}, h0, 0, rl.WHITE)
		h1 :: TILE_SIZE / 2
		h += h1
		rl.DrawLineV({0, h}, {view.x, h}, rl.WHITE)
		rl.DrawTextEx(font, LETTERS_IN_FONT, {0, h - h1}, h1, 0, rl.WHITE)
		h2 :: TILE_SIZE / 4
		h += h2
		rl.DrawLineV({0, h}, {view.x, h}, rl.WHITE)
		rl.DrawTextEx(font, LETTERS_IN_FONT, {0, h - h2}, h2, 0, rl.WHITE)
	}
}

// Reads the debug keys. Lines for things not ported yet (battles, shops,
// darkness, runners, sounds, player speed) are commented out.
debug_update :: proc() {
	when !ODIN_DEBUG do return // debug builds only

	// if rl.IsKeyPressed(.B) {
	// 	if battle.active {
	// 		fmt.printfln("%#v", battle)
	// 	}
	// }
	if rl.IsKeyPressed(.C) {
		fmt.printfln("%#v", playable_characters)
	}
	// if rl.IsKeyPressed(.D) {
	// 	if darkness < 250 {
	// 		darkness += 50
	// 	} else {
	// 		darkness = 0
	// 	}
	// 	fmt.printfln("darkness = %d", darkness)
	// }
	if rl.IsKeyPressed(.E) {
		moogle_charm = !moogle_charm
		fmt.printfln("Moogle Charm mode %s", moogle_charm ? "ACTIVE" : "INACTIVE")
	}
	if rl.IsKeyPressed(.F) {debug_framerate = !debug_framerate}
	if rl.IsKeyPressed(.G) {debug_grid = !debug_grid}
	if rl.IsKeyPressed(.I) {
		force_drops = !force_drops
		fmt.printfln("Force item drops mode %s", force_drops ? "ACTIVE" : "INACTIVE")
	}
	if rl.IsKeyPressed(.T) {debug_text = !debug_text}
	// if rl.IsKeyPressed(.H) {
	// 	shop_enter(&demo_shop)
	// 	// fmt.printfln("%#v", shop_menu_data)
	// }

	// if rl.IsKeyPressed(.M) {
	// 	if battle_menu.ui_state != .Inactive {
	// 		fmt.printfln("%#v\n%#v", battle_menu.ui_state, battle_menu.ui_data)
	// 	} else if shop_menu_active() {
	// 		fmt.printfln("%#v\n%#v", shop_menu_data.ui_state, shop_menu_data.ui_data)
	// 	} else if world_menu_active() {
	// 		// fmt.printfln("%#v\n%#v", world_menu.ui_state, world_menu.ui_data)
	// 	}
	// }

	// if rl.IsKeyPressed(.P) {
	// 	battle.debug_pause = !battle.debug_pause
	// 	fmt.printfln("Battle force-pause %s", battle.debug_pause ? "ON" : "OFF")
	// }

	// if rl.IsKeyPressed(.R) {
	// 	fmt.printfln("%#v", runners)
	// }

	if rl.IsKeyPressed(.ONE) {
		debug_toggle_pc(0)
	} else if rl.IsKeyPressed(.TWO) {
		debug_toggle_pc(1)
	} else if rl.IsKeyPressed(.THREE) {
		debug_toggle_pc(2)
	} else if rl.IsKeyPressed(.FOUR) {
		debug_toggle_pc(3)
	} else if rl.IsKeyPressed(.FIVE) {
		debug_toggle_pc(4)
	} else if rl.IsKeyPressed(.SIX) {
		debug_toggle_pc(5)
	}

	if rl.IsKeyPressed(.GRAVE) {
		// Vsync (main sets VSYNC_HINT) caps frames at the refresh rate too, so
		// unthrottling turns it off as well as raylib's own limiter.
		throttle = !throttle
		if throttle {
			rl.SetWindowState({.VSYNC_HINT})
			rl.SetTargetFPS(THROTTLED_FPS)
		} else {
			rl.ClearWindowState({.VSYNC_HINT})
			rl.SetTargetFPS(0) // no limit
		}
		fmt.println("FPS throttling", throttle)
	}

	if rl.IsKeyPressed(.PERIOD) {
		sudden_death = !sudden_death
		fmt.printfln("Baddy sudden death mode %s", sudden_death ? "ACTIVE" : "INACTIVE")
	}

	// if rl.IsKeyPressed(.SLASH) {
	// 	get_world_entity(PLAYER_ID).speed = 12
	// 	fmt.println("Super speed!")
	// }

	if debug_framerate {
		dt := rl.GetFrameTime()
		if debug_framerate_sum >= DEBUG_FRAMERATE_PERIOD {
			debug_framerate_count = 1
			debug_framerate_sum = dt
		} else {
			debug_framerate_count += 1
			debug_framerate_sum += dt
		}
	}
}

// Adds or removes a PC from the party; the last member stays.
debug_toggle_pc :: proc(pc_idx: int) {
	if world_menu_active() {
		return
	}
	if game_data.party_membership[pc_idx] {
		if party_size() > 1 {
			game_data.party_membership[pc_idx] = false
			play_sound(.Kaching)
		} else {
			play_sound(.Blerp)
		}
	} else {
		game_data.party_membership[pc_idx] = true
		play_sound(.Warp)
	}
}
