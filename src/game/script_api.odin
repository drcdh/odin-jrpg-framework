package game

import "core:fmt"
import "core:log"
import "core:strings"
import rl "vendor:raylib"

import "../rules"

// --- Immediate verbs: usable anywhere. Each cancels any tween on the property it sets. ---

// Teleports: sets the logical tile and snaps the sprite onto it.
set_tile :: proc(id: Entity_Id, tile: Tile) {
	tween_cancel_target(Entity_Prop{id, .Pos})
	if e, ok := entity_get(id); ok {
		e.tile = tile
		e.pos = tile_center(tile)
	}
}

// Makes `id` busy, so it stops wandering or following a path while something
// interacts with it: for every script but the running one, move_entity,
// move_entity_to (and so walk_entity and walk_route) wait as if blocked, and
// set_facing does nothing. Ends with set_busy(id, false) or when the script
// that set it ends. From the main thread, it holds off all scripts.
set_busy :: proc(id: Entity_Id, busy := true) {
	if e, ok := entity_get(id); ok {
		e.busy = busy
		e.busy_by = current_script.handle if busy && current_script != nil else {}
	}
}

// set_busy on the player. While the player is busy, the game ignores movement
// and interact input (see is_busy), e.g. during a scripted pause.
set_busy_player :: proc(busy := true) {
	set_busy(player(), busy)
}

// Does nothing from a script while the entity is busy with another (set_busy).
set_facing :: proc(id: Entity_Id, dir: Direction) {
	if entity_busy(id) do return
	if e, ok := entity_get(id); ok do e.facing = dir
}

set_facing_player :: proc(id: Entity_Id) {
	set_facing(id, dir_opposite(entity_get(player()).facing))
}

set_tint :: proc(id: Entity_Id, tint:= rl.WHITE) {
	tween_cancel_target(Entity_Prop{id, .Tint})
	if e, ok := entity_get(id); ok do e.sprite.tint = tint
}

set_scale :: proc(id: Entity_Id, scale: [2]f32) {
	tween_cancel_target(Entity_Prop{id, .Scale})
	if e, ok := entity_get(id); ok do e.sprite.scale = scale
}

set_rotation :: proc(id: Entity_Id, degrees: f32) {
	tween_cancel_target(Entity_Prop{id, .Rotation})
	if e, ok := entity_get(id); ok do e.sprite.rotation = degrees
}

set_visible :: proc(id: Entity_Id, visible: bool) {
	if e, ok := entity_get(id); ok do e.sprite.hidden = !visible
}

// Removes `id`'s talk trigger, e.g. after a one-time gift. A script running
// from it carries on.
clear_trigger :: proc(id: Entity_Id) {
	if e, ok := entity_get(id); ok do e.trigger.script = nil
}

// Sets the screen curtain at once: 1 is black, 0 clear. E.g. a cutscene
// starting dark, then fading in with fade_screen.
set_curtain :: proc(alpha: f32) {
	tween_cancel_target(&world.curtain)
	world.curtain = alpha
}

// Sprite playback on an entity. Only switches rows and frames of an already
// loaded sheet, so these are safe from scripts.

// Shows `tag` on `id`'s sprite. Turns off follow_facing, so the tag sticks on
// a walker (e.g. Downed); set_follow_facing restores it. Warns if the sheet
// has no such row.
set_sprite_tag_of :: proc(id: Entity_Id, tag: Sprite_Tag, reset := true, loc := #caller_location) {
	e, ok := entity_get(id)
	if !ok do return
	if m, has_meta := state_metadata(e.sprite); has_meta && m.type == .Tagged {
		if _, has := tag_index(m.tags, tag); !has do log.warnf("%v's sprite has no %v tag", e.name, tag, location = loc)
	}
	e.sprite.follow_facing = false
	set_sprite_tag(&e.sprite, tag, reset)
}

// When `id`'s sprite animates: always, only while moving, or never.
set_anim_when :: proc(id: Entity_Id, mode: Anim_When) {
	if e, ok := entity_get(id); ok do e.sprite.anim_when = mode
}

// `id`'s walking speed, in seconds per tile; it sticks (see Entity.step_time).
set_step_time :: proc(id: Entity_Id, seconds_per_tile: f32) {
	if e, ok := entity_get(id); ok do e.step_time = seconds_per_tile
}

// Whether `id`'s sprite keeps to the row for its facing (walker sprites do).
// Turning it back on snaps the row to the facing on the next update.
set_follow_facing :: proc(id: Entity_Id, follow := true) {
	if e, ok := entity_get(id); ok do e.sprite.follow_facing = follow
}

play_anim :: proc(id: Entity_Id) {
	if e, ok := entity_get(id); ok do play_sprite(&e.sprite)
}

stop_anim :: proc(id: Entity_Id) {
	if e, ok := entity_get(id); ok do stop_sprite(&e.sprite)
}

freeze_anim :: proc(id: Entity_Id, frame: u16) {
	if e, ok := entity_get(id); ok do freeze_sprite(&e.sprite, frame)
}

// --- Blocking verbs: scripts only. They return false if the script was cancelled. ---

// Waits in game time, so it respects set_paused and set_time_scale.
pause :: proc(seconds: f32, loc := #caller_location) -> bool {
	return yield_until(Wait_Time{world.clock.time + f64(seconds)}, loc)
}

next_frame :: proc(loc := #caller_location) -> bool {
	return yield_until(Wait_Frame{}, loc)
}

// Waits until the tween finishes, is cancelled or replaced, or loses its target.
// Loop and Ping_Pong tweens never finish on their own.
wait_tween :: proc(t: Tween_Id, loc := #caller_location) -> bool {
	return yield_until(Wait_Tween{t}, loc)
}

wait_all :: proc(tweens: ..Tween_Id, loc := #caller_location) -> bool {
	for t in tweens do if !wait_tween(t, loc) do return false
	return true
}

wait_script :: proc(s: Script_Id, loc := #caller_location) -> bool {
	return yield_until(Wait_Script{s}, loc)
}

// `pred` runs on the main thread once per frame until it returns true.
wait_until :: proc(pred: proc(data: rawptr) -> bool, data: rawptr = nil, loc := #caller_location) -> bool {
	return yield_until(Wait_Pred{pred, data}, loc)
}

// One slide of `delta` tiles. The logical tile jumps to the destination at the
// start, so for long moves prefer walk_entity. Waits first while the entity is
// busy with another script (set_busy).
move_entity :: proc(id: Entity_Id, delta: Tile, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	if !wait_not_busy(id, loc) do return false
	return wait_tween(tween_to_tile(id, entity_tile(id) + delta, duration, easing), loc)
}

move_entity_to :: proc(id: Entity_Id, to: Tile, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	if !wait_not_busy(id, loc) do return false
	return wait_tween(tween_to_tile(id, to, duration, easing), loc)
}

// Blocks while another solid entity is on `tile` (see tile_occupied).
wait_tile_clear :: proc(id: Entity_Id, tile: Tile, loc := #caller_location) -> bool {
	Blocked :: struct { id: Entity_Id, tile: Tile }
	b := Blocked{id, tile} // on this script's stack, which outlives the wait
	return wait_until(proc(data: rawptr) -> bool {
		blocked := (^Blocked)(data)
		return !tile_occupied(blocked.tile, blocked.id)
	}, &b, loc)
}

// Blocks while `id` is busy with another script (see set_busy).
wait_not_busy :: proc(id: Entity_Id, loc := #caller_location) -> bool {
	assert(current_script != nil, "wait_not_busy called outside of a script", loc)
	Held :: struct { id: Entity_Id, by: Script_Id }
	h := Held{id, current_script.handle} // on this script's stack, which outlives the wait
	return wait_until(proc(data: rawptr) -> bool {
		held := (^Held)(data)
		return !entity_held(held.id, held.by)
	}, &h, loc)
}

// Walks one tile at a time, x first and then y, facing each step's direction.
// The entity's tile always matches the cell it's drawn in. Each step takes the
// entity's step_time; a non-nil `seconds_per_tile` overwrites it first (and
// it sticks). `pause_between` waits that long between tiles (not after the
// last one).
// Before each step it waits for the next tile to be clear of solid entities,
// and while the entity is busy with another script (set_busy).
walk_entity :: proc(id: Entity_Id, delta: Tile, seconds_per_tile: Maybe(f32) = nil, pause_between: f32 = 0, loc := #caller_location) -> bool {
	if s, ok := seconds_per_tile.?; ok do set_step_time(id, s)
	first := true
	for axis in 0..<2 {
		n := delta[axis]
		if n == 0 do continue
		step: Tile
		step[axis] = 1 if n > 0 else -1
		dir := Direction.Right if n > 0 else .Left
		if axis == 1 do dir = .Down if n > 0 else .Up
		for _ in 0..<abs(n) {
			if !first && pause_between > 0 && !pause(pause_between, loc) do return false
			first = false
			for {
				if !wait_not_busy(id, loc) do return false
				set_facing(id, dir)
				if !wait_tile_clear(id, entity_tile(id) + step, loc) do return false
				// It may have been made busy, or moved, while it waited.
				if !entity_busy(id) && !tile_occupied(entity_tile(id) + step, id) do break
			}
			if !move_entity_to(id, entity_tile(id) + step, entity_step_time(id), loc = loc) do return false
		}
	}
	return true
}

// Walks `id` to `to` by a shortest route round impassable map tiles (see
// find_path), one tile at a time, and blocks until it's there. Entities in the
// way are waited for, as in walk_entity, not routed round. `pause_between`
// waits between tiles (not after the last one). A non-nil `seconds_per_tile`
// overwrites the entity's step_time, as in walk_entity. Returns false if the
// script was cancelled or `to` can't be reached from where `id` stands (logged).
walk_to :: proc(id: Entity_Id, to: Tile, seconds_per_tile: Maybe(f32) = nil, pause_between: f32 = 0, loc := #caller_location) -> bool {
	if s, ok := seconds_per_tile.?; ok do set_step_time(id, s)
	from := entity_tile(id)
	steps, ok := find_path(from, to)
	defer delete(steps)
	if !ok {
		log.warnf("%v can't reach %v from %v", id, to, from, location = loc)
		return false
	}
	for step, i in steps {
		if i > 0 && pause_between > 0 && !pause(pause_between, loc) do return false
		if !walk_entity(id, step, loc = loc) do return false
	}
	return true
}

// Flashes the whole screen and blocks until the flash has faded out.
flash_screen :: proc(color: rl.Color, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	return wait_tween(tween_flash(color, duration, easing), loc)
}

// Tweens the screen curtain to `alpha` (1 black, 0 clear) and blocks until
// it's there: fade_screen(0, t) fades in, fade_screen(1, t) fades to black.
fade_screen :: proc(alpha: f32, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	return wait_tween(curtain_to(alpha, duration, easing), loc)
}

// Pans the camera onto `id` at `speed` tiles per second and blocks until it
// arrives; the camera then follows `id`.
pan_camera_follow :: proc(id: Entity_Id, speed: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	assert(speed > 0, "a pan needs a speed; use camera_follow to snap", loc)
	camera_follow(id, speed, easing)
	return wait_until(proc(_: rawptr) -> bool { return !camera_panning() }, loc = loc)
}

// Pans the camera onto `tile` at `speed` tiles per second and blocks until it
// arrives; the camera then stays there.
pan_camera_to_tile :: proc(tile: Tile, speed: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	assert(speed > 0, "a pan needs a speed; use camera_to_tile to snap", loc)
	camera_to_tile(tile, speed, easing)
	return wait_until(proc(_: rawptr) -> bool { return !camera_panning() }, loc = loc)
}

// Walks route[0] → route[1] → … tile by tile. By default it closes the loop
// back to route[0] (one lap); with `once` it stops on the last vertex, and the
// route needn't close. Every leg walked must be straight: its two vertices
// differ in only one dimension. The entity should start on route[0].
// `pause_between` waits between tiles and at each corner, but not after the
// final tile. A non-nil `seconds_per_tile` overwrites the entity's step_time,
// as in walk_entity.
walk_route :: proc(id: Entity_Id, route: []Tile, seconds_per_tile: Maybe(f32) = nil, pause_between: f32 = 0, once := false, loc := #caller_location) -> bool {
	assert(len(route) >= 2, "a route needs at least two vertices", loc)
	if s, ok := seconds_per_tile.?; ok do set_step_time(id, s)
	legs := once ? len(route) - 1 : len(route)
	for i in 0..<legs {
		from, to := route[i], route[(i + 1) % len(route)]
		assert(from.x == to.x || from.y == to.y, "route legs must be straight: adjacent vertices may differ in x or y, not both", loc)
		if i > 0 && pause_between > 0 && !pause(pause_between, loc) do return false
		if !walk_entity(id, to - entity_tile(id), pause_between = pause_between, loc = loc) do return false
	}
	return true
}

tint_to :: proc(id: Entity_Id, tint: rl.Color, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	return wait_tween(tween_tint(id, tint, duration, easing), loc)
}

fade_to :: proc(id: Entity_Id, alpha: u8, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	return wait_tween(tween_alpha(id, alpha, duration, easing), loc)
}

scale_to :: proc(id: Entity_Id, scale: [2]f32, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	return wait_tween(tween_scale(id, scale, duration, easing), loc)
}

rotate_to :: proc(id: Entity_Id, degrees: f32, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	return wait_tween(tween_rotation(id, degrees, duration, easing), loc)
}

rotate_by :: proc(id: Entity_Id, degrees: f32, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	return wait_tween(tween_by(id, .Rotation, {degrees, 0, 0, 0}, duration, easing), loc)
}

// Adds `items` to the inventory and says so: "Got Potion x2, Tea!". Does
// nothing without items.
get_items :: proc(items: ..rules.Item_Name, loc := #caller_location) -> bool {
	if len(items) == 0 do return true
	counts: [rules.Item_Name]int
	for item in items {
		rules.add_item(item)
		counts[item] += 1
	}
	names := make([dynamic]string, 0, len(items), context.temp_allocator)
	for item in items { // in order of first appearance
		n := counts[item]
		if n == 0 do continue
		append(&names, n == 1 ? rules.items[item].name : fmt.tprintf("%s x%d", rules.items[item].name, n))
		counts[item] = 0
	}
	return say(strings.concatenate({"Got ", strings.join(names[:], ", ", context.temp_allocator), "!"}, context.temp_allocator), loc = loc)
}
