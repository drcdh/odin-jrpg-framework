package engine

import rl "vendor:raylib"

// --- Immediate verbs: usable anywhere. Each cancels any tween on the property it sets. ---

// Teleports: sets the logical tile and snaps the sprite onto it.
set_tile :: proc(id: Entity_Id, tile: Tile) {
	tween_cancel_target(Entity_Prop{id, .Pos})
	if e, ok := entity_get(id); ok {
		e.tile = tile
		e.pos = tile_center(tile)
	}
}

set_busy :: proc(id: Entity_Id, busy := false) {
  if e, ok := entity_get(id); ok do e.busy = busy
}

set_facing :: proc(id: Entity_Id, dir: Direction) {
	if e, ok := entity_get(id); ok do e.facing = dir
}

set_facing_player :: proc(id: Entity_Id) {
  set_facing(id, dir_opposite(entity_get(player()).facing))
}

set_tint :: proc(id: Entity_Id, tint: rl.Color) {
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

// Sprite playback on an entity. Only switches rows and frames of an already
// loaded sheet, so these are safe from scripts.
set_sprite_tag_of :: proc(id: Entity_Id, tag: Sprite_Tag, reset := true) {
	if e, ok := entity_get(id); ok do set_sprite_tag(&e.sprite, tag, reset)
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
// start, so for long moves prefer walk_entity.
move_entity :: proc(id: Entity_Id, delta: Tile, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	return wait_tween(tween_to_tile(id, entity_tile(id) + delta, duration, easing), loc)
}

move_entity_to :: proc(id: Entity_Id, to: Tile, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
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

// Walks one tile at a time, x first and then y, facing each step's direction.
// The entity's tile always matches the cell it's drawn in. `pause_between`
// waits that long between tiles (not after the last one).
// Before each step it waits for the next tile to be clear of solid entities.
walk_entity :: proc(id: Entity_Id, delta: Tile, seconds_per_tile: f32, pause_between: f32 = 0, loc := #caller_location) -> bool {
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
			set_facing(id, dir)
			next := entity_tile(id) + step
			if !wait_tile_clear(id, next, loc) do return false
			if !wait_tween(tween_to_tile(id, next, seconds_per_tile), loc) do return false
		}
	}
	return true
}

// Flashes the whole screen and blocks until the flash has faded out.
flash_screen :: proc(color: rl.Color, duration: f32, easing := Ease.Linear, loc := #caller_location) -> bool {
	return wait_tween(tween_flash(color, duration, easing), loc)
}

// Walks the closed loop route[0] → route[1] → … → route[0] once, tile by tile.
// Adjacent vertices must differ in only one dimension, so every leg is a
// straight line. The entity should start on route[0]. `pause_between` waits
// between tiles and at each corner, but not after the final tile.
walk_route :: proc(id: Entity_Id, route: []Tile, seconds_per_tile: f32, pause_between: f32 = 0, loc := #caller_location) -> bool {
	assert(len(route) >= 2, "a route needs at least two vertices", loc)
	for i in 0..<len(route) {
		from, to := route[i], route[(i + 1) % len(route)]
		assert(from.x == to.x || from.y == to.y, "route legs must be straight: adjacent vertices may differ in x or y, not both", loc)
		if i > 0 && pause_between > 0 && !pause(pause_between, loc) do return false
		if !walk_entity(id, to - entity_tile(id), seconds_per_tile, pause_between, loc) do return false
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
