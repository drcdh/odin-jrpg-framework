package game

import hm "core:container/handle_map"
import "core:math"
import "core:slice"
import "core:strings"
import "core:testing"
import rl "vendor:raylib"

// Headless: no window. Each test owns the global world, so run with ODIN_TEST_THREADS=1.

@(private = "file")
FRAME :: f32(1.0 / 50.0)

// Advances `seconds` of game time in FRAME steps, running a full update per frame.
@(private = "file")
run_for :: proc(seconds: f32) {
	for _ in 0..<int(math.round(seconds / FRAME)) do update(FRAME)
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
	testing.expect_value(t, hm.len(game.tweens), 0)
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
	e := spawn_entity({sprite = {tint = rl.WHITE}})
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
	testing.expect_value(t, hm.len(game.tweens), 1)
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
		started := game.clock.time
		pause(0.5)
		resumed_at = game.clock.time - started
	})
	run_for(1)
	// At most one frame late (f32 dt accumulation can land just short of the deadline).
	testing.expectf(t, resumed_at >= 0.5 - 0.0001 && resumed_at <= 0.5 + f64(FRAME) + 0.0001, "paused for %v", resumed_at)
	testing.expect_value(t, len(game.script_order), 0)
	testing.expect_value(t, hm.len(game.scripts), 0)
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
	wait_all_entity = spawn_entity({})
	s := spawn(proc(self: Entity_Id) {
		a := tween_by(self, .Pos_X, {10, 0, 0, 0}, 0.2)
		b := tween_by(self, .Rotation, {90, 0, 0, 0}, 0.6)
		wait_all(a, b)
		resumed_at = game.clock.time
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
		resumed_at = game.clock.time
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
	testing.expect_value(t, len(game.script_order), 0)
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
	for len(game.script_order) > 0 && frames < 100 {
		for h in game.script_order do script_cancel(h)
		run_for(FRAME)
		frames += 1
	}
	testing.expect_value(t, len(game.script_order), 0)
}

@(test)
script_spawned_by_script_and_waited_on :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn(proc(_: Entity_Id) {
		child := spawn(proc(_: Entity_Id) { pause(0.3) })
		wait_script(child)
		resumed_at = game.clock.time
	})
	run_for(0.6)
	testing.expectf(t, resumed_at >= 0.3 && resumed_at < 0.4, "resumed at %v", resumed_at)
}

@(test)
script_drives_entity_found_by_name :: proc(t: ^testing.T) {
	init(); defer shutdown()
	light := spawn_entity({name = "light", sprite = {tint = rl.BLACK}})
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
		resumed_at = game.clock.time
	})
	run_for(FRAME)
	testing.expect_value(t, game.flash.color, rl.Color{255, 0, 0, 200})
	expect_near(t, game.flash.alpha, 200)
	run_for(0.1)
	testing.expect(t, game.flash.alpha > 0 && game.flash.alpha < 200)
	run_for(0.25)
	expect_near(t, game.flash.alpha, 0)
	testing.expectf(t, resumed_at >= 0.25, "resumed at %v", resumed_at)
}

@(test)
new_flash_replaces_old :: proc(t: ^testing.T) {
	init(); defer shutdown()
	a := tween_flash(rl.RED, 1)
	run_for(0.5)
	b := tween_flash(rl.BLUE, 0.25)
	testing.expect(t, tween_done(a))
	testing.expect_value(t, game.flash.color, rl.BLUE)
	expect_near(t, game.flash.alpha, 255)
	run_for(0.3)
	testing.expect(t, tween_done(b))
	expect_near(t, game.flash.alpha, 0)
}

@(test)
walk_entity_pauses_between_tiles :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({tile = {0, 0}})
	s := spawn(proc(self: Entity_Id) { walk_entity(self, {2, 0}, 0.2, pause_between = 0.25) }, e)

	// Step 1 runs ~0.02-0.22, then it rests until ~0.47; step 2 runs ~0.47-0.67.
	run_for(0.35)
	testing.expect_value(t, entity_tile(e), Tile{1, 0})
	testing.expect_value(t, entity_pos(e), tile_center({1, 0}))
	run_for(0.2)
	testing.expect_value(t, entity_tile(e), Tile{2, 0})
	run_for(0.2)
	testing.expect(t, !script_alive(s), "no pause after the last tile")
	testing.expect_value(t, entity_pos(e), tile_center({2, 0}))
}

// --- Sprites ---
// These add a Sprite record with no image, so all the
// frame/row/playback logic runs without a window.

@(private = "file") hero_tags   := [?]Sprite_Tag{.Left, .Down, .Right, .Up, .Cheer}
@(private = "file") hero_frames := [?]u16{2, 2, 2, 2, 3}
@(private = "file") blink_frames := [?]u16{4}

@(private = "file")
hero_meta :: proc() -> Sprite_Metadata {
	return {frame_size = {16, 24}, type = .Tagged, tags = hero_tags[:], num_frames = hero_frames[:], frame_t = 150}
}

@(private = "file")
blink_meta :: proc() -> Sprite_Metadata {
	return {frame_size = {8, 8}, type = .Anim, num_frames = blink_frames[:], frame_t = 100}
}

// Made-up sheets, so the tests don't depend on what's in assets/sprites.
@(private = "file")
fake_sprite :: proc(m: Sprite_Metadata) -> Sprite_State {
	h, _ := hm.add(&game.sprites, Sprite{meta = m})
	s := Sprite_State{sprite = h, tint = rl.WHITE, origin = {0.5, 0.5}, scale = {1, 1}, speed = 1}
	if m.type == .Tagged do s.tag = m.tags[0]
	return s
}

@(test)
sprite_src_uses_frame_column_and_tag_row :: proc(t: ^testing.T) {
	init(); defer shutdown()
	s := fake_sprite(hero_meta())
	testing.expect_value(t, s.tag, Sprite_Tag.Left) // first tag by default
	testing.expect_value(t, sprite_src(s), rl.Rectangle{0, 0, 16, 24})
	s.tag = .Right
	s.frame = 1
	testing.expect_value(t, sprite_src(s), rl.Rectangle{16, 48, 16, 24})
	s.tag = .Cheer
	testing.expect_value(t, sprite_src(s).y, 96)

	b := fake_sprite(blink_meta())
	b.frame = 3
	testing.expect_value(t, sprite_src(b), rl.Rectangle{24, 0, 8, 8})
}

@(test)
update_sprite_advances_and_loops :: proc(t: ^testing.T) {
	init(); defer shutdown()
	s := fake_sprite(blink_meta())
	testing.expect(t, !update_sprite(0.5, &s), "not playing yet")
	testing.expect_value(t, s.frame, 0)

	play_sprite(&s)
	update_sprite(0.05, &s)
	testing.expect_value(t, s.frame, 0)
	update_sprite(0.06, &s)
	testing.expect_value(t, s.frame, 1)

	s.speed = 2 // 50 ms per frame
	update_sprite(0.05, &s)
	testing.expect_value(t, s.frame, 2)
	update_sprite(0.05, &s)
	testing.expect_value(t, s.frame, 3)
	testing.expect(t, update_sprite(0.05, &s), "wrapping to frame 0 reports a loop")
	testing.expect_value(t, s.frame, 0)
}

@(test)
static_sprite_never_animates :: proc(t: ^testing.T) {
	init(); defer shutdown()
	s := fake_sprite({frame_size = {16, 16}, type = .Static})
	play_sprite(&s)
	testing.expect(t, !update_sprite(10, &s))
	testing.expect_value(t, s.frame, 0)
	testing.expect_value(t, animation_length(s), 0)
}

@(test)
sprite_playback_controls :: proc(t: ^testing.T) {
	init(); defer shutdown()
	s := fake_sprite(hero_meta())
	play_sprite(&s)
	update_sprite(0.16, &s)
	testing.expect_value(t, s.frame, 1)

	freeze_sprite(&s, 0)
	update_sprite(1, &s)
	testing.expect_value(t, s.frame, 0)
	unfreeze_sprite(&s)
	update_sprite(0.16, &s)
	testing.expect_value(t, s.frame, 1)

	set_sprite_tag(&s, .Cheer, reset = false)
	testing.expect(t, s.anim && s.frame == 1, "no reset keeps playback")
	set_sprite_tag(&s, .Up)
	testing.expect(t, !s.anim && s.frame == 0 && s.time == 0, "reset stops at frame 0")
	testing.expect_value(t, get_sprite_tag(s), Sprite_Tag.Up)

	play_sprite(&s)
	update_sprite(0.16, &s)
	stop_sprite(&s)
	testing.expect(t, !s.anim && s.frame == 0)
}

@(test)
animation_length_per_row :: proc(t: ^testing.T) {
	init(); defer shutdown()
	b := fake_sprite(blink_meta())
	expect_near(t, animation_length(b), 0.4)
	h := fake_sprite(hero_meta())
	expect_near(t, animation_length(h), 0.3) // 2 frames x 150 ms
	h.tag = .Cheer
	expect_near(t, animation_length(h), 0.45)
}

@(test)
follow_facing_switches_row_and_keeps_playing :: proc(t: ^testing.T) {
	init(); defer shutdown()
	s := fake_sprite(hero_meta())
	s.follow_facing = true
	s.anim = true
	s.frame = 1
	e := spawn_entity({facing = .Up, sprite = s})
	b := fake_sprite(blink_meta())
	b.follow_facing = true // no direction rows: ignored
	other := spawn_entity({facing = .Right, sprite = b})

	sprites_update(0)
	testing.expect_value(t, entity_get(e).sprite.tag, Sprite_Tag.Up)
	testing.expect(t, entity_get(e).sprite.anim && entity_get(e).sprite.frame == 1, "row switch keeps playback")
	testing.expect_value(t, entity_get(other).sprite.tag, Sprite_Tag.Left) // zero value, untouched

	// Moving to a row with fewer frames wraps the frame.
	entity_get(e).sprite.tag = .Cheer
	entity_get(e).sprite.frame = 2
	set_facing(e, .Down)
	sprites_update(0)
	testing.expect_value(t, entity_get(e).sprite.tag, Sprite_Tag.Down)
	testing.expect_value(t, entity_get(e).sprite.frame, 0)
}

@(test)
moving_sprite_animates_one_stride_per_tile :: proc(t: ^testing.T) {
	init(); defer shutdown()
	s := fake_sprite(hero_meta()) // Left row: 2 frames x 150 ms, a 0.3 s loop
	s.anim = true
	s.anim_when = .Moving
	e := spawn_entity({tile = {0, 0}, sprite = s, step_time = 1})

	run_for(1)
	testing.expect_value(t, entity_get(e).sprite.frame, 0) // still: holds the start pose

	// One tile in 1 s: the 0.3 s loop stretched to 1 s, starting halfway
	// through frame 0, so frame 1 fills the middle half of the tile.
	tween_to_tile(e, {1, 0}, 1)
	run_for(0.15)
	testing.expect_value(t, entity_get(e).sprite.frame, 0)
	run_for(0.35)
	testing.expect_value(t, entity_get(e).sprite.frame, 1)
	run_for(0.35)
	testing.expect_value(t, entity_get(e).sprite.frame, 0)
	run_for(0.3)
	testing.expect_value(t, entity_get(e).sprite.frame, 0) // arrived
	testing.expectf(t, abs(entity_get(e).sprite.time - 0.075) < 1e-6, "holds half of frame 0, got %v", entity_get(e).sprite.time)
}

@(test)
anim_when_always_and_never :: proc(t: ^testing.T) {
	init(); defer shutdown()
	s := fake_sprite(hero_meta())
	s.anim = true
	e := spawn_entity({tile = {0, 0}, sprite = s}) // Always, the default
	run_for(0.2)
	testing.expect_value(t, entity_get(e).sprite.frame, 1) // animates while still

	set_anim_when(e, .Never)
	tween_to_tile(e, {1, 0}, 1)
	run_for(0.5)
	testing.expect_value(t, entity_get(e).sprite.frame, 1) // not even while moving

	set_anim_when(e, .Moving)
	run_for(0.6)
	testing.expect_value(t, entity_get(e).sprite.frame, 0) // arrived: start pose
}

@(test)
walk_speed_belongs_to_the_entity :: proc(t: ^testing.T) {
	init(); defer shutdown()
	plain := spawn_entity({})
	testing.expect_value(t, entity_get(plain).step_time, DEFAULT_STEP_TIME)
	hero := spawn_entity({sprite = fake_sprite(hero_meta())})
	testing.expectf(t, abs(entity_get(hero).step_time - 0.3) < 1e-6, "1x: one loop per tile, got %v", entity_get(hero).step_time)

	e := spawn_entity({tile = {0, 0}})
	s := spawn(proc(self: Entity_Id) {
		walk_entity(self, {1, 0}, 0.2) // overwrites the speed...
		walk_entity(self, {1, 0})      // ...which sticks
	}, e)
	run_for(0.3)
	testing.expect_value(t, entity_get(e).step_time, 0.2)
	testing.expect_value(t, entity_tile(e), Tile{2, 0}) // second step under way at 0.2 s
	run_for(0.2)
	testing.expect(t, !script_alive(s), "two tiles at 0.2 s each take 0.4 s")
	testing.expect_value(t, entity_get(e).pos, tile_center({2, 0}))
}

@(test)
set_sprite_tag_of_overrides_follow_facing :: proc(t: ^testing.T) {
	init(); defer shutdown()
	s := fake_sprite(hero_meta())
	s.follow_facing = true
	e := spawn_entity({facing = .Up, sprite = s})

	set_sprite_tag_of(e, .Cheer)
	sprites_update(0)
	testing.expect_value(t, entity_get(e).sprite.tag, Sprite_Tag.Cheer)
	set_facing(e, .Left)
	sprites_update(0)
	testing.expect_value(t, entity_get(e).sprite.tag, Sprite_Tag.Cheer) // facing no longer wins

	set_follow_facing(e)
	sprites_update(0)
	testing.expect_value(t, entity_get(e).sprite.tag, Sprite_Tag.Left)
}

@(test)
create_sprite_state_without_window :: proc(t: ^testing.T) {
	init(); defer shutdown()
	s := create_sprite_state(.Man_Ps, tint = rl.GOLD, play = true, speed = 2, follow_facing = true, layer = 3)
	testing.expect_value(t, s.sprite, Sprite_Handle{})
	testing.expect_value(t, s.tint, rl.GOLD)
	testing.expect_value(t, s.scale, [2]f32{1, 1})
	testing.expect_value(t, s.origin, [2]f32{0.5, 0.5})
	testing.expect(t, s.anim && s.speed == 2 && s.follow_facing && s.layer == 3)
}

@(private = "file") test_route := [?]Tile{{0, 0}, {2, 0}, {2, 1}, {0, 1}}

@(test)
walk_route_loops_back_to_start :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({tile = test_route[0]})
	s := spawn(proc(self: Entity_Id) { walk_route(self, test_route[:], 0.1, pause_between = 0.05) }, e)

	visited := make([dynamic]Tile, context.temp_allocator)
	append(&visited, entity_tile(e))
	for frame := 0; script_alive(s) && frame < 500; frame += 1 {
		run_for(FRAME)
		if tile := entity_tile(e); tile != visited[len(visited) - 1] do append(&visited, tile)
	}
	want := []Tile{{0, 0}, {1, 0}, {2, 0}, {2, 1}, {1, 1}, {0, 1}, {0, 0}}
	testing.expect(t, !script_alive(s), "walk_route should finish one lap")
	testing.expectf(t, slice.equal(visited[:], want), "visited %v", visited[:])
	testing.expect_value(t, entity_get(e).facing, Direction.Up) // last leg goes up
}

// The closing leg (2,2) → (0,0) is diagonal: fine, since `once` never walks it.
@(private = "file") test_open_route := [?]Tile{{0, 0}, {2, 0}, {2, 2}}
@(private = "file") test_open_route_ok: bool

@(test)
walk_route_once_stops_at_last_vertex :: proc(t: ^testing.T) {
	init(); defer shutdown()
	test_open_route_ok = false
	e := spawn_entity({tile = test_open_route[0]})
	s := spawn(proc(self: Entity_Id) {
		test_open_route_ok = walk_route(self, test_open_route[:], 0.1, pause_between = 0.05, once = true)
	}, e)

	visited := make([dynamic]Tile, context.temp_allocator)
	append(&visited, entity_tile(e))
	for frame := 0; script_alive(s) && frame < 500; frame += 1 {
		run_for(FRAME)
		if tile := entity_tile(e); tile != visited[len(visited) - 1] do append(&visited, tile)
	}
	want := []Tile{{0, 0}, {1, 0}, {2, 0}, {2, 1}, {2, 2}}
	testing.expect(t, !script_alive(s), "walk_route should finish")
	testing.expect(t, test_open_route_ok, "walk_route should return true")
	testing.expectf(t, slice.equal(visited[:], want), "visited %v", visited[:])
	testing.expect_value(t, entity_get(e).facing, Direction.Down) // last leg goes down
}

// --- Input and dialogue ---

// Presses `k` for one frame, then releases it.
@(private = "file")
tap :: proc(k: Game_Input) {
	game.input.state[k] = Input_Pressed{}
	run_for(FRAME)
	game.input.state[k] = Input_Up{}
}

// The dialogue page as typed out so far, lines joined with "\n".
@(private = "file")
dialogue_text :: proc() -> string {
	d := &game.dialogue
	b := strings.builder_make(context.temp_allocator)
	text := strings.to_string(d.buffer)
	remaining := d.shown
	for l, i in d.page[:d.page_len] {
		if i > 0 do strings.write_byte(&b, '\n')
		n := min(l.end - l.start, remaining)
		remaining -= n
		strings.write_string(&b, text[l.start:][:n])
	}
	return strings.to_string(b)
}

@(private = "file")
dialogue_is :: proc($T: typeid) -> bool {
	_, ok := game.dialogue.state.(T)
	return ok
}

@(test)
input_states_press_hold_release :: proc(t: ^testing.T) {
	s: Single_Input_State = Input_Up{}
	s = next_input_state(s, true, 0.1)
	testing.expect_value(t, s, Single_Input_State(Input_Pressed{}))
	s = next_input_state(s, true, 0.1)
	testing.expect_value(t, s, Single_Input_State(Input_Held{t = 0.1}))
	s = next_input_state(s, true, 0.2)
	expect_near(t, s.(Input_Held).t, 0.3)
	s = next_input_state(s, false, 0.1)
	testing.expect_value(t, s, Single_Input_State(Input_Up{}))
}

@(test)
get_input_repeats_after_hold_time :: proc(t: ^testing.T) {
	init(); defer shutdown()
	game.input.state[.ENTER] = Input_Pressed{}
	testing.expect(t, get_input(.ENTER))
	game.input.state[.ENTER] = Input_Held{t = 0.5}
	testing.expect(t, !get_input(.ENTER))
	testing.expect(t, get_input(.ENTER, down = true))
	game.input.state[.ENTER] = Input_Held{t = HOLD_TIME}
	testing.expect(t, get_input(.ENTER))
	consume_input(.ENTER)
	testing.expect(t, !get_input(.ENTER))
	consume_input(.UP) // up stays up
	testing.expect_value(t, game.input.state[.UP], Single_Input_State(Input_Up{}))

	game.input.state[.UP] = Input_Pressed{}
	game.input.state[.RIGHT] = Input_Held{t = 2}
	testing.expect_value(t, get_menu_input(), [2]int{1, -1})
	testing.expect_value(t, get_y_input(), Maybe(int)(-1))
}

@(test)
wrap_page_breaks_at_spaces_and_newlines :: proc(t: ^testing.T) {
	out: [MAX_DIALOGUE_LINES]Dialogue_Line
	lines :: proc(text: string, out: []Dialogue_Line) -> []string {
		r := make([dynamic]string, context.temp_allocator)
		for l in out do append(&r, text[l.start:l.end])
		return r[:]
	}

	text := "the quick brown fox jumps"
	n, next := wrap_page(text, 0, 4, 10, out[:])
	testing.expect(t, slice.equal(lines(text, out[:n]), []string{"the quick", "brown fox", "jumps"}))
	testing.expect_value(t, next, len(text))

	text = "abcdefghij klm\nx"
	n, next = wrap_page(text, 0, 4, 10, out[:])
	testing.expect(t, slice.equal(lines(text, out[:n]), []string{"abcdefghij", "klm", "x"}))

	text = "abcdefghijklm"
	n, next = wrap_page(text, 0, 4, 10, out[:])
	testing.expect(t, slice.equal(lines(text, out[:n]), []string{"abcdefghij", "klm"}))

	text = "1\n2\n3"
	n, next = wrap_page(text, 0, 2, 10, out[:])
	testing.expect_value(t, n, 2)
	testing.expect_value(t, text[next:], "3")
}

@(test)
say_types_then_waits_for_enter :: proc(t: ^testing.T) {
	init(); defer shutdown()
	trigger_count = 0
	s := spawn(proc(_: Entity_Id) {
		say("first", "Tester")
		trigger_count = 1
		say("second")
		trigger_count = 2
	})
	run_for(FRAME * 3)
	testing.expect(t, dialogue_is(Dialogue_Marquee))
	testing.expect(t, len(dialogue_text()) < len("first"), "still typing")

	run_for(0.5)
	testing.expect(t, dialogue_is(Dialogue_Wait))
	testing.expect_value(t, dialogue_text(), "first")
	testing.expect_value(t, strings.to_string(game.dialogue.speaker), "Tester")
	testing.expect_value(t, trigger_count, 0)

	tap(.ENTER)
	run_for(FRAME)
	testing.expect_value(t, trigger_count, 1)
	testing.expect(t, dialogue_active(), "the conversation carries on")
	run_for(0.5)
	testing.expect_value(t, dialogue_text(), "second")
	testing.expect_value(t, strings.builder_len(game.dialogue.speaker), 0)

	tap(.ENTER)
	run_for(FRAME)
	testing.expect_value(t, trigger_count, 2)
	testing.expect(t, !dialogue_active())
	testing.expect(t, !script_alive(s))
}

@(test)
enter_skips_typing :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn(proc(_: Entity_Id) { say("a fairly long line of text") })
	run_for(FRAME)
	tap(.ENTER)
	testing.expect_value(t, dialogue_text(), "a fairly long line of text")
	testing.expect(t, dialogue_is(Dialogue_Wait))
	tap(.ENTER)
	run_for(FRAME)
	testing.expect(t, !dialogue_active())
}

@(test)
opening_press_does_not_skip :: proc(t: ^testing.T) {
	init(); defer shutdown()
	game.input.state[.ENTER] = Input_Pressed{} // the press that talked to someone
	spawn(proc(_: Entity_Id) { say("hello there") })
	run_for(FRAME)
	testing.expect(t, dialogue_is(Dialogue_Marquee))
	testing.expect(t, len(dialogue_text()) < len("hello there"))
}

@(test)
say_pages_long_text :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn(proc(_: Entity_Id) { say("1\n2\n3\n4\n5\n6") })
	run_for(0.5)
	testing.expect_value(t, dialogue_text(), "1\n2\n3\n4")
	testing.expect(t, dialogue_is(Dialogue_Wait))
	tap(.ENTER)
	run_for(0.5)
	testing.expect_value(t, dialogue_text(), "5\n6")
	tap(.ENTER)
	run_for(FRAME)
	testing.expect(t, !dialogue_active())
}

@(test)
speaker_takes_a_line :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn(proc(_: Entity_Id) { say("1\n2\n3\n4\n5\n6", "Sage") })
	run_for(0.5)
	testing.expect_value(t, dialogue_text(), "1\n2\n3")
	tap(.ENTER)
	run_for(0.5)
	testing.expect_value(t, dialogue_text(), "4\n5\n6")
}

@(test)
say_appends_without_clear :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn(proc(_: Entity_Id) {
		say("a", hurry = true)
		say(" b", clear = false)
	})
	run_for(0.5)
	testing.expect_value(t, dialogue_text(), "a b")
}

@(test)
hurry_and_pause_need_no_enter :: proc(t: ^testing.T) {
	init(); defer shutdown()
	trigger_count = 0
	spawn(proc(_: Entity_Id) {
		say("hi", hurry = true, pause = 0.5)
		trigger_count = 1
	})
	run_for(0.3)
	testing.expect(t, dialogue_is(Dialogue_Pause))
	testing.expect_value(t, trigger_count, 0)
	run_for(0.4)
	testing.expect_value(t, trigger_count, 1)
	testing.expect(t, !dialogue_active())
}

@(private = "file") chosen: int

@(test)
choose_wraps_and_returns_the_pick :: proc(t: ^testing.T) {
	init(); defer shutdown()
	chosen = -1
	spawn(proc(_: Entity_Id) {
		c, ok := choose("Pick one", {"a", "b", "c"})
		if ok do chosen = c
	})
	run_for(0.5)
	testing.expect(t, dialogue_is(Dialogue_Choose))
	testing.expect_value(t, len(game.dialogue.choices), 3)
	tap(.UP)
	testing.expect_value(t, game.dialogue.choice, 2)
	tap(.DOWN)
	tap(.DOWN)
	testing.expect_value(t, game.dialogue.choice, 1)
	tap(.ENTER)
	run_for(FRAME)
	testing.expect_value(t, chosen, 1)
	testing.expect(t, !dialogue_active())
	testing.expect_value(t, len(game.dialogue.choices), 0)
}

@(test)
say_waits_for_other_speaker :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn(proc(_: Entity_Id) { say("a") })
	spawn(proc(_: Entity_Id) { say("b") })
	run_for(0.2)
	testing.expect_value(t, dialogue_text(), "a")
	tap(.ENTER)
	run_for(0.2)
	testing.expect_value(t, dialogue_text(), "b")
	tap(.ENTER)
	run_for(FRAME)
	testing.expect(t, !dialogue_active())
}

@(test)
cancelled_speaker_closes_its_dialogue :: proc(t: ^testing.T) {
	init(); defer shutdown()
	npc := spawn_entity({})
	spawn(proc(_: Entity_Id) { say("bye") }, npc)
	run_for(FRAME)
	testing.expect(t, dialogue_active())
	destroy_entity(npc)
	run_for(FRAME * 2)
	testing.expect(t, !dialogue_active())
	testing.expect_value(t, len(game.script_order), 0)
}

@(private = "file") trigger_count: int

@(private = "file")
count_and_wait :: proc(_: Entity_Id) {
	trigger_count += 1
	pause(1)
}

// --- Busy ---

// Makes its entity busy, faces it up, holds for 0.5 s, then frees it.
@(private = "file")
hold_busy :: proc(self: Entity_Id) {
	set_facing(self, .Up)
	set_busy(self)
	pause(0.5)
	set_facing(self, .Down) // the holder may still change it
	set_busy(self, false)
}

@(test)
busy_holds_off_other_scripts_moves_and_facing :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({tile = {0, 0}, facing = .Right, sprite = {tint = rl.WHITE}})
	spawn(hold_busy, e)
	run_for(FRAME)
	testing.expect(t, entity_get(e).busy)

	mover := spawn(proc(self: Entity_Id) {
		set_facing(self, .Left)  // ignored
		set_tint(self, rl.RED)   // not affected by busy
		move_entity(self, {1, 0}, 0.1) // waits
	}, e)
	run_for(FRAME)
	testing.expect_value(t, entity_get(e).facing, Direction.Up)
	testing.expect_value(t, entity_get(e).sprite.tint, rl.RED)
	testing.expect_value(t, entity_tile(e), Tile{0, 0})

	set_facing(e, .Left) // the main thread isn't held off
	testing.expect_value(t, entity_get(e).facing, Direction.Left)

	run_for(0.5)
	testing.expect(t, !entity_get(e).busy)
	testing.expect_value(t, entity_get(e).facing, Direction.Down) // set by the holder
	run_for(0.2)
	testing.expect_value(t, entity_tile(e), Tile{1, 0})
	testing.expect(t, !script_alive(mover))
}

@(test)
busy_holds_off_walks :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({tile = {0, 0}})
	walker := spawn(proc(self: Entity_Id) { walk_entity(self, {3, 0}, 0.1) }, e)
	run_for(0.12) // second step under way
	spawn(hold_busy, e)
	run_for(0.3)
	testing.expect_value(t, entity_tile(e), Tile{2, 0}) // finished its step, then stopped
	testing.expect_value(t, entity_get(e).facing, Direction.Up)
	run_for(0.5)
	testing.expect_value(t, entity_tile(e), Tile{3, 0})
	testing.expect_value(t, entity_get(e).facing, Direction.Right)
	testing.expect(t, !script_alive(walker))
}

@(test)
busy_lapses_when_its_script_ends :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({facing = .Right})
	spawn(proc(self: Entity_Id) { set_busy(self) }, e)
	run_for(FRAME)
	spawn(proc(self: Entity_Id) { set_facing(self, .Left) }, e)
	run_for(FRAME)
	testing.expect_value(t, entity_get(e).facing, Direction.Left)
}

@(test)
is_busy_follows_its_script :: proc(t: ^testing.T) {
	init(); defer shutdown()
	e := spawn_entity({})
	spawn(proc(self: Entity_Id) {
		set_busy(self)
		pause(0.5) // ends without set_busy(false)
	}, e)
	run_for(FRAME)
	testing.expect(t, is_busy(e))
	run_for(0.6)
	testing.expect(t, !is_busy(e), "busy lapses with its script")

	set_busy(e) // from the main thread: held until cleared
	run_for(0.5)
	testing.expect(t, is_busy(e))
	set_busy(e, false)
	testing.expect(t, !is_busy(e))
}

@(test)
trigger_autoface_and_autobusy :: proc(t: ^testing.T) {
	init(); defer shutdown()
	p := spawn_entity({tile = {0, 0}, facing = .Right})
	npc := spawn_entity({tile = {1, 0}, facing = .Up, trigger = new_trigger(proc(self: Entity_Id) {
		set_facing(self, .Down) // the trigger script itself may change it
		pause(0.5)
	})})
	pacer := spawn(proc(self: Entity_Id) { walk_entity(self, {0, 3}, 0.1) }, npc)

	testing.expect(t, interact(p))
	testing.expect_value(t, entity_get(npc).facing, Direction.Left)
	testing.expect(t, entity_get(npc).busy)
	run_for(0.3)
	testing.expect_value(t, entity_tile(npc), Tile{1, 0}) // the pacer is held off
	testing.expect_value(t, entity_get(npc).facing, Direction.Down)

	run_for(0.3)
	testing.expect(t, !entity_get(npc).busy, "busy ends with the trigger script")
	run_for(0.5)
	testing.expect_value(t, entity_tile(npc), Tile{1, 3})
	testing.expect(t, !script_alive(pacer))
}

@(test)
plain_trigger_neither_faces_nor_busies :: proc(t: ^testing.T) {
	init(); defer shutdown()
	p := spawn_entity({tile = {0, 0}, facing = .Right})
	npc := spawn_entity({tile = {1, 0}, facing = .Up, trigger = new_trigger(proc(self: Entity_Id) {
		set_busy(self) // busy set by the script itself is cleared at the end too
	}, autoface = false, autobusy = false)})

	testing.expect(t, interact(p))
	testing.expect_value(t, entity_get(npc).facing, Direction.Up)
	testing.expect(t, !entity_get(npc).busy)
	run_for(FRAME)
	testing.expect(t, !entity_get(npc).busy)
	testing.expect(t, !script_alive(entity_get(npc).trigger.running))
}

// --- Maps, camera, levels ---

@(test)
map_gid_lookup :: proc(t: ^testing.T) {
	// Two tilesets in Tiled order; the second starts at gid 17.
	ids := []Tileset_Id{.Tileset_Terrain, .Tileset_Terrain}
	m := Level_Map{tilesets = ids, firstgids = []int{1, 17}}
	_, empty := map_gid_tile(m, 0)
	testing.expect_value(t, empty, -1)
	_, first := map_gid_tile(m, 1)
	testing.expect_value(t, first, 0)
	_, last_of_first := map_gid_tile(m, 16)
	testing.expect_value(t, last_of_first, 15)
	_, first_of_second := map_gid_tile(m, 17)
	testing.expect_value(t, first_of_second, 0)
	_, later := map_gid_tile(m, 20)
	testing.expect_value(t, later, 3)
	_, no_tilesets := map_gid_tile({}, 5)
	testing.expect_value(t, no_tilesets, -1)
}

@(test)
map_contains_edges :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {20, 10}})
	testing.expect(t, map_contains({0, 0}))
	testing.expect(t, map_contains({19, 9}))
	testing.expect(t, !map_contains({20, 9}))
	testing.expect(t, !map_contains({19, 10}))
	testing.expect(t, !map_contains({-1, 0}))
}

@(test)
map_render_headless_is_noop :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {2, 2}, tilesets = []Tileset_Id{.Tileset_Terrain}, firstgids = []int{1}})
	begin_map_render()
	draw_map_tile(1, 0, 0)
	end_map_render()
	testing.expect_value(t, game.world.level_map.rt.id, 0)
}

@(test)
camera_follows_tweened_pos :: proc(t: ^testing.T) {
	init(); defer shutdown()
	p := spawn_entity({tile = {5, 5}})
	camera_follow(p)
	camera_update()
	testing.expect_value(t, game.world.camera.target, tile_center({5, 5}))
	testing.expect_value(t, game.world.camera.offset, [2]f32{WINDOW_WIDTH, WINDOW_HEIGHT} / 2)

	tween_to_tile(p, {6, 5}, 1)
	run_for(0.5)
	camera_update()
	testing.expect(t, game.world.camera.target.x > tile_center({5, 5}).x && game.world.camera.target.x < tile_center({6, 5}).x,
		"camera between tiles mid-step")

	// DEFAULT mode: no clamping past the map edge.
	set_map({size = {20, 20}})
	set_tile(p, {0, 0})
	camera_update()
	testing.expect_value(t, game.world.camera.target, tile_center({0, 0}))
}

@(test)
camera_snaps_to_tile_and_entity :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {20, 20}})
	camera_to_tile({7, 3})
	run_for(FRAME)
	testing.expect_value(t, game.world.camera.target, tile_center({7, 3}))
	testing.expect(t, !camera_panning())

	e := spawn_entity({tile = {2, 9}})
	camera_follow(e)
	run_for(FRAME)
	testing.expect_value(t, game.world.camera.target, tile_center({2, 9}))
	testing.expect_value(t, camera_followed(), e)
}

@(test)
camera_pans_to_tile_at_speed :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {20, 20}})
	camera_to_tile({2, 2})
	run_for(FRAME)
	camera_to_tile({6, 2}, speed = 2) // 4 tiles at 2 tiles/s: 2 s
	run_for(1)
	testing.expect(t, camera_panning(), "still panning at 1 s")
	testing.expectf(t, abs(game.world.camera.target.x - tile_center({4, 2}).x) < 1, "halfway, got %v", game.world.camera.target)
	run_for(1.1)
	testing.expect(t, !camera_panning(), "pan done at 2 s")
	testing.expect_value(t, game.world.camera.target, tile_center({6, 2}))
}

@(test)
camera_pans_onto_moving_entity :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {20, 20}})
	camera_to_tile({0, 0})
	run_for(FRAME)
	e := spawn_entity({tile = {4, 4}})
	tween_to_tile(e, {8, 4}, 4) // still walking when the pan ends
	camera_follow(e, speed = 4)
	for frame := 0; camera_panning() && frame < 500; frame += 1 do run_for(FRAME)
	testing.expect(t, !camera_panning(), "the pan should end")
	testing.expect_value(t, game.world.camera.target, entity_get(e).pos)
	run_for(0.5)
	testing.expect_value(t, game.world.camera.target, entity_get(e).pos) // and follows after
}

@(test)
pan_camera_to_tile_blocks_until_there :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {20, 20}})
	camera_to_tile({0, 0})
	run_for(FRAME)
	s := spawn(proc(_: Entity_Id) { pan_camera_to_tile({3, 0}, 3) }) // 1 s
	run_for(0.5)
	testing.expect(t, script_alive(s), "still panning")
	run_for(0.6)
	testing.expect(t, !script_alive(s), "pan_camera_to_tile returns once the pan is done")
	testing.expect_value(t, game.world.camera.target, tile_center({3, 0}))
}

@(test)
camera_clamps_in_clamp_mode :: proc(t: ^testing.T) {
	init(); defer shutdown()
	half := [2]f32{WINDOW_WIDTH, WINDOW_HEIGHT} / 2
	map_size := [2]f32{20, 20} * TILE_SIZE // bigger than the view
	p := spawn_entity({tile = {0, 0}})
	camera_follow(p)
	set_map({size = {20, 20}})
	set_map_mode(.CLAMP)

	camera_update()
	testing.expect_value(t, game.world.camera.target, half)
	set_tile(p, {19, 19})
	camera_update()
	testing.expect_value(t, game.world.camera.target, map_size - half)
	set_tile(p, {10, 10})
	camera_update()
	testing.expect_value(t, game.world.camera.target, tile_center({10, 10}))

	// A map narrower than the view is centered on that axis.
	set_map({size = {4, 20}, mode = .CLAMP})
	camera_update()
	testing.expect_value(t, game.world.camera.target, [2]f32{32, tile_center({10, 10}).y})
}

@(test)
clear_level_removes_everything :: proc(t: ^testing.T) {
	init(); defer shutdown()
	p := spawn_entity({tile = {1, 1}})
	set_player(p)
	camera_follow(p)
	tw := tween_to_tile(p, {2, 1}, 1)
	s := spawn(proc(_: Entity_Id) { pause(10) }, p, "long")
	set_map({size = {8, 8}})
	run_for(FRAME)

	clear_level()
	testing.expect_value(t, hm.len(game.entities), 0)
	testing.expect(t, tween_done(tw))
	run_for(FRAME) // cancelled scripts finish on their next resume
	testing.expect(t, !script_alive(s))
	testing.expect_value(t, game.world.level_map.size, Tile{})
	testing.expect_value(t, game.world.player, Entity_Id{})
	testing.expect(t, game.world.camera.focus == nil, "the camera still has a focus")
}

// A 4x3 map whose column x == 2 is impassable.
@(private = "file")
WALL_COLUMN := [12]u8{
	0, 0, PARTY_IMPASSABLE, 0,
	0, 0, PARTY_IMPASSABLE, 0,
	0, 0, PARTY_IMPASSABLE, 0,
}

// A 5x3 map walled at x == 2 except for a gap at (2, 2).
@(private = "file")
WALL_WITH_GAP := [15]u8{
	0, 0, PARTY_IMPASSABLE, 0, 0,
	0, 0, PARTY_IMPASSABLE, 0, 0,
	0, 0, 0,                0, 0,
}

@(test)
find_path_goes_round_walls :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {5, 3}, passable = WALL_WITH_GAP[:]})
	steps, ok := find_path({0, 0}, {4, 0}, context.temp_allocator)
	testing.expect(t, ok)
	testing.expect_value(t, len(steps), 8) // down 2, right 4, up 2
	at := Tile{0, 0}
	for s in steps {
		testing.expectf(t, abs(s.x) + abs(s.y) == 1, "not a unit step: %v", s)
		at += s
		testing.expectf(t, tile_passable(at), "walked onto the wall at %v", at)
	}
	testing.expect_value(t, at, Tile{4, 0})

	steps, ok = find_path({1, 1}, {1, 1}, context.temp_allocator)
	testing.expect(t, ok && len(steps) == 0, "already there")

	set_map({size = {4, 3}, passable = WALL_COLUMN[:]})
	_, ok = find_path({0, 0}, {3, 0}, context.temp_allocator)
	testing.expect(t, !ok, "the far side of a solid wall is unreachable")
}

@(test)
find_path_crosses_the_wrap_seam :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {6, 1}, mode = .WRAP})
	steps, ok := find_path({0, 0}, {5, 0}, context.temp_allocator)
	testing.expect(t, ok)
	testing.expect_value(t, len(steps), 1)
	testing.expect_value(t, steps[0], Tile{-1, 0})
}

@(private = "file") walk_to_result: bool

@(test)
walk_to_goes_through_the_gap :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {5, 3}, passable = WALL_WITH_GAP[:]})
	walk_to_result = false
	e := spawn_entity({tile = {0, 0}})
	s := spawn(proc(self: Entity_Id) { walk_to_result = walk_to(self, {4, 0}, 0.1) }, e)
	for frame := 0; script_alive(s) && frame < 500; frame += 1 {
		run_for(FRAME)
		testing.expectf(t, tile_passable(entity_tile(e)), "on the wall at %v", entity_tile(e))
	}
	testing.expect(t, !script_alive(s), "walk_to should finish")
	testing.expect(t, walk_to_result, "walk_to should return true")
	testing.expect_value(t, entity_tile(e), Tile{4, 0})
}

@(test)
walk_to_unreachable_returns_false :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {4, 3}, passable = WALL_COLUMN[:]})
	walk_to_result = true
	e := spawn_entity({tile = {0, 0}})
	s := spawn(proc(self: Entity_Id) { walk_to_result = walk_to(self, {3, 0}, 0.1) }, e)
	run_for(0.5)
	testing.expect(t, !script_alive(s))
	testing.expect(t, !walk_to_result, "walk_to should return false")
	testing.expect_value(t, entity_tile(e), Tile{0, 0})
}

@(test)
tile_free_checks_passability :: proc(t: ^testing.T) {
	init(); defer shutdown()
	set_map({size = {4, 3}})
	testing.expect(t, tile_free({2, 1}), "no passability: everything free")

	set_map({size = {4, 3}, passable = WALL_COLUMN[:]})
	testing.expect(t, tile_free({1, 1}))
	testing.expect(t, !tile_free({2, 0}))
	testing.expect(t, !tile_free({2, 2}))
	testing.expect(t, !tile_free({2, 3}), "outside a closed map is blocked")
	testing.expect(t, !tile_free({-1, 0}))

	set_map({size = {4, 3}, passable = WALL_COLUMN[:], open_edges = true})
	testing.expect(t, !tile_free({2, 1}))
	testing.expect(t, tile_free({2, 3}), "outside a map with open edges is free")
	testing.expect(t, tile_free({-1, 0}))

	set_map_mode(.WRAP)
	testing.expect(t, !tile_free({6, 1}), "wraps to x == 2")
	testing.expect(t, !tile_free({-2, 5}), "wraps to (2, 2)")
	testing.expect(t, tile_free({7, 1}))

	// Only the party bit blocks.
	boat_only := [12]u8{0 ..< 12 = BOAT_IMPASSABLE}
	set_map({size = {4, 3}, passable = boat_only[:]})
	testing.expect(t, tile_free({2, 0}))
}

@(test)
entities_block_unless_ghost :: proc(t: ^testing.T) {
	init(); defer shutdown()
	a := spawn_entity({tile = {0, 0}})
	spawn_entity({tile = {1, 0}})
	spawn_entity({tile = {2, 0}, ghost = true})
	g := spawn_entity({tile = {3, 0}, ghost = true})

	testing.expect(t, !tile_free({1, 0}, a), "solid entity blocks")
	testing.expect(t, tile_free({2, 0}, a), "ghost doesn't block")
	testing.expect(t, tile_free({0, 0}, a), "a mover doesn't block itself")
	testing.expect(t, !tile_free({0, 0}), "no mover: every solid entity counts")
	testing.expect(t, tile_free({1, 0}, g), "a ghost mover is never blocked")

	// A move claims its destination as soon as it starts.
	tween_to_tile(a, {0, 1}, 1)
	testing.expect(t, !tile_free({0, 1}))
	testing.expect(t, tile_free({0, 0}))
}

@(test)
walk_entity_waits_for_blocker :: proc(t: ^testing.T) {
	init(); defer shutdown()
	walker  := spawn_entity({tile = {0, 0}})
	blocker := spawn_entity({tile = {2, 0}})
	s := spawn(proc(self: Entity_Id) { walk_entity(self, {3, 0}, 0.1) }, walker)

	run_for(1)
	testing.expect_value(t, entity_tile(walker), Tile{1, 0})
	testing.expect(t, script_alive(s), "waiting behind the blocker")

	set_tile(blocker, {2, 1})
	run_for(0.5)
	testing.expect_value(t, entity_tile(walker), Tile{3, 0})
	testing.expect(t, !script_alive(s))
}

@(test)
ghost_walks_through :: proc(t: ^testing.T) {
	init(); defer shutdown()
	ghost := spawn_entity({tile = {0, 0}, ghost = true})
	spawn_entity({tile = {1, 0}})
	s := spawn(proc(self: Entity_Id) { walk_entity(self, {2, 0}, 0.1) }, ghost)
	run_for(0.5)
	testing.expect_value(t, entity_tile(ghost), Tile{2, 0})
	testing.expect(t, !script_alive(s))
}

@(private = "file")
step_count: int
@(private = "file")
step_by: Entity_Id

@(test)
step_trigger_fires_on_arrival :: proc(t: ^testing.T) {
	init(); defer shutdown()
	step_count = 0
	pad := spawn_entity({tile = {2, 0}, ghost = true, on_step = proc(_, by: Entity_Id) {
		step_count += 1
		step_by = by
	}})
	walker := spawn_entity({tile = {0, 0}})
	// The arriving entity's own on_step isn't called.
	spawn_entity({tile = {9, 9}, on_step = proc(_, _: Entity_Id) { step_count += 100 }})

	tween_to_tile(walker, {1, 0}, 0.1)
	run_for(0.2)
	testing.expect_value(t, step_count, 0)

	tw := tween_to_tile(walker, {2, 0}, 0.1)
	testing.expect_value(t, step_count, 0) // not when the move starts
	run_for(0.2)
	testing.expect(t, tween_done(tw))
	testing.expect_value(t, step_count, 1)
	testing.expect_value(t, step_by, walker)

	// A cancelled move doesn't arrive.
	set_tile(walker, {1, 0})
	tw = tween_to_tile(walker, {2, 0}, 0.5)
	run_for(0.1)
	tween_cancel(tw)
	run_for(0.5)
	testing.expect_value(t, step_count, 1)

	// walk_entity arrives on each tile it steps through.
	set_tile(walker, {0, 0})
	spawn(proc(self: Entity_Id) { walk_entity(self, {3, 0}, 0.1) }, walker)
	run_for(1)
	testing.expect_value(t, entity_tile(walker), Tile{3, 0})
	testing.expect_value(t, step_count, 2)
	_ = pad
}

@(test)
clear_level_ends_global_scripts_and_tweens :: proc(t: ^testing.T) {
	init(); defer shutdown()
	value: f32
	tw := tween_f32(&value, 1, 10)
	s := spawn(proc(_: Entity_Id) { pause(10) }, {}, "global")
	run_for(FRAME)
	clear_level()
	testing.expect(t, tween_done(tw))
	run_for(FRAME)
	testing.expect(t, !script_alive(s))
}

@(test)
curtain_tweens :: proc(t: ^testing.T) {
	init(); defer shutdown()
	tw := curtain_to(1, 0.2)
	run_for(0.1)
	testing.expect(t, game.curtain > 0.3 && game.curtain < 0.7, "halfway")
	run_for(0.2)
	testing.expect(t, tween_done(tw))
	testing.expect_value(t, game.curtain, 1)
}

@(test)
set_curtain_cancels_fade_and_fade_screen_blocks :: proc(t: ^testing.T) {
	init(); defer shutdown()
	tw := curtain_to(0.5, 1)
	set_curtain(1)
	testing.expect(t, tween_done(tw), "set_curtain cancels a running fade")
	testing.expect_value(t, game.curtain, 1)

	s := spawn(proc(_: Entity_Id) { fade_screen(0, 0.2) })
	run_for(0.1)
	testing.expect(t, script_alive(s) && game.curtain > 0.3 && game.curtain < 0.7, "mid fade")
	run_for(0.2)
	testing.expect(t, !script_alive(s), "fade_screen returns once the fade is done")
	testing.expect_value(t, game.curtain, 0)
}

@(test)
palette_swaps_are_cached :: proc(t: ^testing.T) {
	init(); defer shutdown()
	lime := Palette_Swap{{rl.SKYBLUE, rl.LIME}}
	lime_again := Palette_Swap{{rl.SKYBLUE, rl.LIME}}
	pink := Palette_Swap{{rl.SKYBLUE, rl.PINK}}
	a := get_sprite_h(.Man_Ps, lime)
	testing.expect_value(t, get_sprite_h(.Man_Ps, lime_again), a)
	testing.expect(t, get_sprite_h(.Man_Ps, pink) != a)
	testing.expect(t, get_sprite_h(.Man_Ps) != a, "unswapped is cached separately")
	testing.expect_value(t, hm.len(game.sprites), 3)
}

@(test)
tag_direction_inverts_direction_tag :: proc(t: ^testing.T) {
	for d in Direction do testing.expect_value(t, tag_direction(direction_tag(d)), d)
	testing.expect_value(t, tag_direction(.Walk), Direction.Down)
}

// --- World menu ---

@(test)
world_menu_pauses_and_cancel_restores_the_clock :: proc(t: ^testing.T) {
	init(); defer shutdown()
	world_menu_enter()
	testing.expect(t, world_menu_active(), "the menu should open")
	testing.expect(t, game.clock.paused, "the menu should pause the world")
	before := time()
	run_for(0.5)
	testing.expect_value(t, time(), before)
	tap(.DOWN) // moves the cursor; the menu stays open
	testing.expect(t, world_menu_active(), "DOWN shouldn't close the menu")
	tap(.CANCEL)
	testing.expect(t, !world_menu_active(), "CANCEL should close the menu")
	testing.expect(t, !game.clock.paused, "closing should unpause")

	// A world paused before the menu opened stays paused after it closes.
	set_paused(true)
	world_menu_enter()
	world_menu_exit()
	testing.expect(t, game.clock.paused, "closing should restore the earlier pause")
}

@(test)
menu_input_opens_the_menu_only_when_the_player_is_free :: proc(t: ^testing.T) {
	init(); defer shutdown()
	p := spawn_entity({name = "player"})
	set_player(p)

	tap(.MENU)
	testing.expect(t, world_menu_active(), "MENU should open the menu when idle")
	game.input.state[.RIGHT] = Input_Held{t = 0.1}
	run_for(0.5)
	game.input.state[.RIGHT] = Input_Up{}
	testing.expect_value(t, entity_tile(p), Tile{0, 0}) // no walking while it's open
	tap(.CANCEL)
	testing.expect(t, !world_menu_active(), "CANCEL should close the menu")

	set_busy(p)
	tap(.MENU)
	testing.expect(t, !world_menu_active(), "MENU shouldn't open the menu while the player is busy")
	set_busy(p, false)

	move := tween_to_tile(p, {3, 0}, 1) // as a script's move_entity would
	tap(.MENU)
	testing.expect(t, !world_menu_active(), "MENU shouldn't open the menu while the player moves")
	run_for(1.1)
	testing.expect(t, tween_done(move), "the move should finish")
	tap(.MENU)
	testing.expect(t, world_menu_active(), "MENU should open the menu once the player stops")
}

@(test)
delayed_sound_waits_on_game_time :: proc(t: ^testing.T) {
	init(); defer shutdown()
	play_sound(.Warp, delay = 0.5)
	run_for(0.4)
	testing.expect_value(t, len(game.audio.pending), 1)
	run_for(0.2)
	testing.expect_value(t, len(game.audio.pending), 0) // no audio device: dropped, not played
}

@(test)
paused_clock_holds_sounds :: proc(t: ^testing.T) {
	init(); defer shutdown()
	play_sound(.Warp, delay = 0.1)
	set_paused(true)
	run_for(1)
	testing.expect_value(t, len(game.audio.pending), 1)
	set_paused(false)
	run_for(0.2)
	testing.expect_value(t, len(game.audio.pending), 0)
}

@(test)
script_queues_sound :: proc(t: ^testing.T) {
	init(); defer shutdown()
	spawn(proc(_: Entity_Id) {
		play_sound(.Whack, delay = 1)
	})
	run_for(FRAME * 2)
	testing.expect_value(t, len(game.audio.pending), 1)
	testing.expect_value(t, game.audio.pending[0].sound, Sound_Name.Whack)
}

@(test)
play_music_remembers_the_previous_track :: proc(t: ^testing.T) {
	init(); defer shutdown()
	testing.expect(t, game.audio.music.thread == nil, "no audio device, so no music thread")
	play_music(.Town)
	play_music(.Cave)
	play_music(.Cave) // the same track again keeps .Town as previous
	testing.expect_value(t, game.audio.music.requested, Music_Name.Cave)
	testing.expect_value(t, game.audio.music.prev, Music_Name.Town)
	play_prev_music()
	testing.expect_value(t, game.audio.music.requested, Music_Name.Town)
	testing.expect_value(t, game.audio.music.prev, Music_Name.Cave)
}

@(test)
music_fades_are_requests :: proc(t: ^testing.T) {
	init(); defer shutdown()
	music_fade_down()
	testing.expect(t, game.audio.music.faded)
	play_music(.Town) // a track change doesn't undo the fade
	testing.expect(t, game.audio.music.faded)
	music_fade_up()
	testing.expect(t, !game.audio.music.faded)
}

@(test)
item_in_world_menu_pops_up_its_result :: proc(t: ^testing.T) {
	init(); defer shutdown()
	init_new_game()
	pc := get_party_member(0)
	pc.stats[Stat_Name.Hitpoints] = 100
	pc.hitpoints = 1
	r := do_skill(nil, 0, .Potion, .World_Menu)
	testing.expect_value(t, r.hp_change, 50)
	testing.expect_value(t, pc.hitpoints, 51)
	testing.expect_value(t, world_menu_popup_count(), 1)
	run_for(1.1) // popups run on raw_dt, which run_for advances too
	testing.expect_value(t, world_menu_popup_count(), 0)
}

@(test)
box_gives_its_items_once :: proc(t: ^testing.T) {
	init(); defer shutdown()
	init_new_game()
	datum := Chest_Datum(0)
	game_data.inventory[Item_Name.Potion] = 0
	set_inventory_order()

	box := spawn_entity({
		name    = "box",
		tile    = {5, 4},
		sprite  = create_sprite_state(.Box, Sprite_Tag.Closed),
		trigger = new_trigger(proc(self: Entity_Id) {
			items_in_a_box(self, Chest_Datum(0), .Potion)
		}, autoface = false),
	})
	opener := spawn_entity({name = "opener", tile = {5, 5}, facing = .Up})

	testing.expect(t, interact(opener), "the box's script didn't start")
	run_for(0.1)
	testing.expect(t, get_game_data(datum), "datum not set")
	testing.expect_value(t, game_data.inventory[Item_Name.Potion], 1)
	testing.expect_value(t, entity_get(box).sprite.tag, Sprite_Tag.Opened)
	testing.expect(t, dialogue_active(), "no message")

	testing.expect(t, !interact(opener), "the box opened twice")
}

@(test)
get_items_groups_duplicates :: proc(t: ^testing.T) {
	init(); defer shutdown()
	init_new_game()
	game_data.inventory[Item_Name.Potion] = 0
	game_data.inventory[Item_Name.Tea] = 0
	spawn(proc(_: Entity_Id) { get_items(.Potion, .Tea, .Potion) })
	run_for(0.1)
	testing.expect_value(t, strings.to_string(game.dialogue.buffer), "Got Potion x2, Tea!")
	testing.expect_value(t, game_data.inventory[Item_Name.Potion], 2)
	testing.expect_value(t, game_data.inventory[Item_Name.Tea], 1)
}

@(test)
level_without_player :: proc(t: ^testing.T) {
	init(); defer shutdown()
	init_new_game()
	start_level(Level(0), with_player = false)
	testing.expect(t, !entity_alive(player()), "a player spawned")
	testing.expect(t, !entity_alive(camera_followed()), "the camera follows something")
	run_for(0.1)
	testing.expect_value(t, current_level(), Level(0))
}

@(test)
script_changes_level :: proc(t: ^testing.T) {
	init(); defer shutdown()
	init_new_game()
	start_level(Level(0), with_player = false)
	spawn(proc(_: Entity_Id) { change_level(Level(0), at = Tile{3, 4}, face = .Left, fade = 0.2) })
	run_for(0.3)
	testing.expect_value(t, current_level(), Level(0))
	testing.expect_value(t, entity_tile(player()), Tile{3, 4})
	testing.expect_value(t, entity_get(player()).facing, Direction.Left)
	testing.expect(t, game.curtain > 0, "already faded in")
	run_for(0.3)
	testing.expect_value(t, game.curtain, 0)
}
