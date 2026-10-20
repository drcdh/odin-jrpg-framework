package engine

import hm "core:container/handle_map"
import "core:math"
import "core:testing"
import rl "vendor:raylib"

// Headless: no window. Each test owns the global world, so run with ODIN_TEST_THREADS=1.

@(private = "file")
FRAME :: f32(1.0 / 50.0)

// Advances `seconds` of game time in FRAME steps, running a full engine update per frame.
@(private = "file")
run_for :: proc(seconds: f32) {
	for _ in 0..<int(math.round(seconds / FRAME)) {
		clock_advance(FRAME)
		update()
	}
}

// Tween tests work in raw pixels; spawn_entity snaps pos to a tile center, so override it.
@(private = "file")
spawn_at :: proc(pos: [2]f32) -> Entity_Id {
	e := spawn_entity({})
	entity_get(e).pos = pos
	return e
}

@(private = "file")
expect_near :: proc(t: ^testing.T, got, want: f32, loc := #caller_location) {
	testing.expectf(t, abs(got - want) < 0.01, "got %v, want %v", got, want, loc = loc)
}

@(test)
tween_once_reaches_end_and_is_removed :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_at({0, 0})
	tw := tween_to(e, .Pos_X, {10, 0, 0, 0}, 1)

	run_for(0.5)
	expect_near(t, entity_pos(e).x, 5)
	testing.expect(t, !tween_done(tw))

	run_for(0.6)
	expect_near(t, entity_pos(e).x, 10)
	testing.expect(t, tween_done(tw))
	testing.expect_value(t, hm.len(world.tweens), 0)
}

@(test)
tween_relative_with_easing :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_at({100, 0})
	tween_by(e, .Pos_X, {20, 0, 0, 0}, 1, .Quadratic_In)

	run_for(0.5)
	expect_near(t, entity_pos(e).x, 100 + 20 * 0.25)
	run_for(1)
	expect_near(t, entity_pos(e).x, 120)
}

@(test)
tween_delay_captures_from_at_start :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_at({0, 0})
	tween_by(e, .Pos_X, {10, 0, 0, 0}, 1, delay = 0.5)

	run_for(0.2)
	entity_get(e).pos.x = 50 // moved before the tween starts
	run_for(0.3 + 1.1)
	expect_near(t, entity_pos(e).x, 60)
}

@(test)
tween_ping_pong_comes_back :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({})
	tw := tween_to(e, .Rotation, {90, 0, 0, 0}, 1, mode = .Ping_Pong)

	run_for(1.5)
	expect_near(t, entity_get(e).sprite.rotation, 45)
	run_for(0.5)
	expect_near(t, entity_get(e).sprite.rotation, 0)
	testing.expect(t, !tween_done(tw))
}

@(test)
tween_tint_lanes_round_trip :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({sprite = sprite_rect({1, 1}, rl.WHITE)})
	tween_tint(e, rl.RED, 0.5)
	run_for(0.6)
	testing.expect_value(t, entity_get(e).sprite.tint, rl.RED)
}

@(test)
tween_on_same_target_replaces :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({})
	a := tween_to(e, .Pos_X, {100, 0, 0, 0}, 1)
	b := tween_to(e, .Pos_X, {-100, 0, 0, 0}, 1)
	testing.expect(t, tween_done(a))
	testing.expect(t, !tween_done(b))
	testing.expect_value(t, hm.len(world.tweens), 1)
}

@(test)
tween_ends_when_entity_is_destroyed :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({})
	tw := tween_to(e, .Pos_X, {100, 0, 0, 0}, 1)
	destroy_entity(e)
	testing.expect(t, entity_alive(e), "destruction is deferred to the end of update")
	run_for(FRAME)
	testing.expect(t, !entity_alive(e))
	testing.expect(t, tween_done(tw))
}

@(test)
tween_raw_f32 :: proc(t: ^testing.T) {
	init(); defer shutdown()
	zoom: f32 = 1
	tween_f32(&zoom, 3, 1)
	run_for(1.1)
	expect_near(t, zoom, 3)
}

@(test)
find_by_name :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn_entity({name = "a"})
	b := spawn_entity({name = "b"})
	testing.expect_value(t, find("b"), b)
	testing.expect_value(t, find("missing"), Entity_Id{})

	destroy_entity(b)
	run_for(FRAME)
	testing.expect_value(t, find("b"), Entity_Id{})
}

// --- Scripts ---

@(private = "file") log_buf: [dynamic]int
@(private = "file") resumed_at: f64

@(test)
script_pause_resumes_on_time :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn(proc(_: Entity_Id) {
		started := world.clock.time
		pause(0.5)
		resumed_at = world.clock.time - started
	})
	run_for(1)
	// At most one frame late (f32 dt accumulation can land just short of the deadline).
	testing.expectf(t, resumed_at >= 0.5 - 0.0001 && resumed_at <= 0.5 + f64(FRAME) + 0.0001, "paused for %v", resumed_at)
	testing.expect_value(t, len(world.script_order), 0)
	testing.expect_value(t, hm.len(world.scripts), 0)
}

@(test)
scripts_run_in_spawn_order_each_frame :: proc(t: ^testing.T) {
	init(); defer shutdown()
	defer delete(log_buf)
	log_buf = make([dynamic]int)
	spawn(proc(_: Entity_Id) { for _ in 0..<3 { append(&log_buf, 1); next_frame() } })
	spawn(proc(_: Entity_Id) { for _ in 0..<3 { append(&log_buf, 2); next_frame() } })
	run_for(FRAME * 5)
	testing.expect(t, len(log_buf) == 6)
	for v, i in log_buf do testing.expect_value(t, v, 1 if i % 2 == 0 else 2)
}

@(private = "file") wait_all_entity: Entity_Id

@(test)
wait_all_waits_for_slowest :: proc(t: ^testing.T) {
	init(); defer shutdown()
	wait_all_entity = spawn_entity({sprite = sprite_rect({1, 1})})
	s := spawn(proc(self: Entity_Id) {
		a := tween_by(self, .Pos_X, {10, 0, 0, 0}, 0.2)
		b := tween_by(self, .Rotation, {90, 0, 0, 0}, 0.6)
		wait_all(a, b)
		resumed_at = world.clock.time
	}, wait_all_entity)
	run_for(0.4)
	testing.expect(t, script_alive(s))
	run_for(0.4)
	testing.expect(t, !script_alive(s))
	testing.expectf(t, resumed_at >= 0.6, "resumed at %v", resumed_at)
	expect_near(t, entity_get(wait_all_entity).sprite.rotation, 90)
}

@(test)
spawn_centers_pos_on_tile :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({tile = {2, 3}, pos = {999, 999}})
	testing.expect_value(t, entity_pos(e), [2]f32{2 * 16 + 8, 3 * 16 + 8})
	testing.expect_value(t, world_to_tile(entity_pos(e)), Tile{2, 3})
}

@(test)
move_entity_sets_tile_then_slides :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({tile = {0, 0}})
	spawn(proc(self: Entity_Id) {
		move_entity(self, {2, 3}, 0.5)
		resumed_at = world.clock.time
	}, e)
	run_for(FRAME)
	testing.expect_value(t, entity_tile(e), Tile{2, 3})
	testing.expect(t, entity_pos(e) != tile_center({2, 3}), "sprite should still be sliding")
	run_for(1)
	testing.expectf(t, resumed_at >= 0.5, "resumed at %v", resumed_at)
	testing.expect_value(t, entity_pos(e), tile_center({2, 3}))
}

@(test)
walk_entity_steps_one_tile_at_a_time :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({tile = {0, 0}})
	spawn(proc(self: Entity_Id) { walk_entity(self, {2, -1}, 0.2) }, e)

	// Steps start at about t = 0.02, 0.22 and 0.42; sample mid-step to stay off frame boundaries.
	run_for(FRAME)
	testing.expect_value(t, entity_tile(e), Tile{1, 0})
	testing.expect_value(t, entity_get(e).facing, Direction.Right)
	run_for(0.3)
	testing.expect_value(t, entity_tile(e), Tile{2, 0})
	run_for(0.2)
	testing.expect_value(t, entity_tile(e), Tile{2, -1})
	testing.expect_value(t, entity_get(e).facing, Direction.Up)
	run_for(0.3)
	testing.expect_value(t, entity_pos(e), tile_center({2, -1}))
}

@(test)
cancel_stops_looping_script :: proc(t: ^testing.T) {
	init(); defer shutdown()
	s := spawn(proc(_: Entity_Id) {
		for pause(0.1) {}
	})
	run_for(0.5)
	testing.expect(t, script_alive(s))
	script_cancel(s)
	run_for(FRAME)
	testing.expect(t, !script_alive(s))
	testing.expect_value(t, len(world.script_order), 0)
}

@(test)
destroying_entity_cancels_its_scripts :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({})
	s := spawn(proc(self: Entity_Id) {
		for move_entity(self, {1, 0}, 1) {}
	}, e)
	run_for(0.3)
	destroy_entity(e)
	run_for(FRAME * 2)
	testing.expect(t, !script_alive(s))
}

@(test)
ignoring_cancel_does_not_hang :: proc(t: ^testing.T) {
	init(); defer shutdown()
	frames := 0
	spawn(proc(_: Entity_Id) {
		// Ignores every result; after cancel each pause still yields one frame.
		for _ in 0..<20 do pause(10)
	})
	run_for(0.1)
	for len(world.script_order) > 0 && frames < 100 {
		for h in world.script_order do script_cancel(h)
		run_for(FRAME)
		frames += 1
	}
	testing.expect_value(t, len(world.script_order), 0)
}

@(test)
script_spawned_by_script_and_waited_on :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn(proc(_: Entity_Id) {
		child := spawn(proc(_: Entity_Id) { pause(0.3) })
		wait_script(child)
		resumed_at = world.clock.time
	})
	run_for(0.6)
	testing.expectf(t, resumed_at >= 0.3 && resumed_at < 0.4, "resumed at %v", resumed_at)
}

@(test)
script_drives_entity_found_by_name :: proc(t: ^testing.T) {
	init(); defer shutdown()
	light := spawn_entity({name = "light", sprite = sprite_rect({1, 1}, rl.BLACK)})
	spawn(proc(_: Entity_Id) {
		l := find("light")
		set_tint(l, rl.RED)
		pause(0.2)
		set_tint(l, rl.BLACK)
	})
	run_for(FRAME)
	testing.expect_value(t, entity_get(light).sprite.tint, rl.RED)
	run_for(0.3)
	testing.expect_value(t, entity_get(light).sprite.tint, rl.BLACK)
}

@(test)
flash_screen_fades_out :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn(proc(_: Entity_Id) {
		flash_screen({255, 0, 0, 200}, 0.25)
		resumed_at = world.clock.time
	})
	run_for(FRAME)
	testing.expect_value(t, world.flash.color, rl.Color{255, 0, 0, 200})
	expect_near(t, world.flash.alpha, 200)
	run_for(0.1)
	testing.expect(t, world.flash.alpha > 0 && world.flash.alpha < 200)
	run_for(0.25)
	expect_near(t, world.flash.alpha, 0)
	testing.expectf(t, resumed_at >= 0.25, "resumed at %v", resumed_at)
}

@(test)
new_flash_replaces_old :: proc(t: ^testing.T) {
	init(); defer shutdown()
	a := tween_flash(rl.RED, 1)
	run_for(0.5)
	b := tween_flash(rl.BLUE, 0.25)
	testing.expect(t, tween_done(a))
	testing.expect_value(t, world.flash.color, rl.BLUE)
	expect_near(t, world.flash.alpha, 255)
	run_for(0.3)
	testing.expect(t, tween_done(b))
	expect_near(t, world.flash.alpha, 0)
}

@(private = "file") trigger_count: int

@(private = "file")
count_and_wait :: proc(_: Entity_Id) {
	trigger_count += 1
	pause(1)
}

@(test)
interact_talks_to_the_faced_tile :: proc(t: ^testing.T) {
	init(); defer shutdown()
	trigger_count = 0
	p := spawn_entity({tile = {5, 5}, facing = .Up})
	npc := spawn_entity({tile = {6, 5}, facing = .Down, trigger = {script = count_and_wait}})

	testing.expect(t, !interact(p), "facing an empty tile")
	run_for(FRAME)
	testing.expect_value(t, trigger_count, 0)

	set_facing(p, .Right)
	testing.expect(t, interact(p))
	testing.expect_value(t, entity_get(npc).facing, Direction.Left) // turned toward the player
	run_for(FRAME)
	testing.expect_value(t, trigger_count, 1)

	testing.expect(t, !interact(p), "script still running")
	run_for(1.2)
	testing.expect(t, interact(p))
	run_for(FRAME)
	testing.expect_value(t, trigger_count, 2)
}

@(test)
interact_once_and_cooldown :: proc(t: ^testing.T) {
	init(); defer shutdown()
	trigger_count = 0
	p := spawn_entity({tile = {0, 0}, facing = .Right})
	spawn_entity({tile = {1, 0}, trigger = {script = proc(_: Entity_Id) { trigger_count += 1 }, mode = .Once}})
	spawn_entity({tile = {0, 1}, trigger = {script = proc(_: Entity_Id) { trigger_count += 10 }, mode = .Cooldown, cooldown = 1}})

	testing.expect(t, interact(p))
	run_for(FRAME)
	testing.expect(t, !interact(p), "Once trigger already fired")

	set_facing(p, .Down)
	testing.expect(t, interact(p))
	run_for(0.5)
	testing.expect(t, !interact(p), "still cooling down")
	run_for(0.6)
	testing.expect(t, interact(p))
	run_for(FRAME)
	testing.expect_value(t, trigger_count, 21)
}
