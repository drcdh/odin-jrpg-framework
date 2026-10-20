package engine

import hm "core:container/handle_map"
import "core:fmt"
import rl "vendor:raylib"

// Trigger radii plus a list of live scripts and what each one is waiting on.
draw_debug :: proc() {
	if !world.debug_overlay do return

	it := hm.iterator_make(&world.entities)
	for e, _ in hm.iterate(&it) {
		if e.trigger.script == nil do continue
		color := rl.GREEN if script_alive(e.trigger.running) else rl.GRAY
		rl.DrawCircleLinesV(e.pos, e.trigger.radius, color)
	}

	FONT :: 16
	x, y: i32 = 10, 10
	line :: proc(x: i32, y: ^i32, text: cstring, color := rl.RAYWHITE) {
		rl.DrawText(text, x, y^, FONT, color)
		y^ += FONT + 2
	}
	line(x, &y, fmt.ctprintf("fps %d   time %.2f   frame %d", rl.GetFPS(), world.clock.time, world.clock.frame))
	line(x, &y, fmt.ctprintf("entities %d   tweens %d   scripts %d",
		hm.len(world.entities), hm.len(world.tweens), len(world.script_order)))
	for h in world.script_order {
		s, ok := hm.get(&world.scripts, h)
		if !ok do continue
		name := s.name if s.name != "" else "<unnamed>"
		color := rl.ORANGE if s.cancel_requested else rl.LIGHTGRAY
		line(x + 10, &y, fmt.ctprintf("%s [%d:%d]  %s", name, h.idx, h.gen, wait_describe(s.wait)), color)
	}
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
