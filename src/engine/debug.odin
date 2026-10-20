package engine

import hm "core:container/handle_map"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// World space (inside BeginMode2D): grid lines, trigger outlines, and the tile the player faces.
draw_debug_world :: proc() {
	if !world.debug_overlay do return

	view := visible_world_rect()
	x0 := math.floor(view.x / TILE_SIZE) * TILE_SIZE
	y0 := math.floor(view.y / TILE_SIZE) * TILE_SIZE
	x1, y1 := view.x + view.width, view.y + view.height
	grid := rl.Color{255, 255, 255, 30}
	for x := x0; x <= x1; x += TILE_SIZE do rl.DrawLineV({x, y0}, {x, y1}, grid)
	for y := y0; y <= y1; y += TILE_SIZE do rl.DrawLineV({x0, y}, {x1, y}, grid)

	it := hm.iterator_make(&world.entities)
	for e, _ in hm.iterate(&it) {
		if e.trigger.script == nil do continue
		color := rl.GREEN if script_alive(e.trigger.running) else rl.GRAY
		rl.DrawRectangleLinesEx(tile_rect(e.tile), 1, color)
	}

	if p, ok := entity_get(world.player); ok {
		rl.DrawRectangleRec(tile_rect(p.tile + dir_vec(p.facing)), {255, 255, 0, 60})
	}
}

// Screen space (after EndMode2D): counters, the player's tile, and each live script's wait.
draw_debug_hud :: proc() {
	if !world.debug_overlay do return

	FONT :: 16
	x, y: i32 = 10, 10
	line :: proc(x: i32, y: ^i32, text: cstring, color := rl.RAYWHITE) {
		rl.DrawText(text, x, y^, FONT, color)
		y^ += FONT + 2
	}
	line(x, &y, fmt.ctprintf("fps %d   time %.2f   frame %d", rl.GetFPS(), world.clock.time, world.clock.frame))
	line(x, &y, fmt.ctprintf("entities %d   tweens %d   scripts %d",
		hm.len(world.entities), hm.len(world.tweens), len(world.script_order)))
	if p, ok := entity_get(world.player); ok {
		line(x, &y, fmt.ctprintf("player tile %v   facing %v", p.tile, p.facing))
	}
	for h in world.script_order {
		s, ok := hm.get(&world.scripts, h)
		if !ok do continue
		name := s.name if s.name != "" else "<unnamed>"
		color := rl.ORANGE if s.cancel_requested else rl.LIGHTGRAY
		line(x + 10, &y, fmt.ctprintf("%s [%d:%d]  %s", name, h.idx, h.gen, wait_describe(s.wait)), color)
	}
}

@(private)
tile_rect :: proc(t: Tile) -> rl.Rectangle {
	return {f32(t.x) * TILE_SIZE, f32(t.y) * TILE_SIZE, TILE_SIZE, TILE_SIZE}
}

@(private)
wait_describe :: proc(w: Wait) -> string {
	switch v in w {
	case Wait_Time:   return fmt.tprintf("pause, %.2fs left", max(v.until - world.clock.time, 0))
	case Wait_Frame:  return "next frame"
	case Wait_Tween:  return fmt.tprintf("tween [%d:%d]", v.tween.idx, v.tween.gen)
	case Wait_Script: return fmt.tprintf("script [%d:%d]", v.script.idx, v.script.gen)
	case Wait_Pred:   return "predicate"
	}
	return "starting"
}
