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

set_facing :: proc(id: Entity_Id, dir: Direction) {
	if e, ok := entity_get(id); ok do e.facing = dir
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

// Walks one tile at a time, x first and then y, facing each step's direction.
// The entity's tile always matches the cell it's drawn in.
walk_entity :: proc(id: Entity_Id, delta: Tile, seconds_per_tile: f32, loc := #caller_location) -> bool {
	for axis in 0..<2 {
		n := delta[axis]
		if n == 0 do continue
		step: Tile
		step[axis] = 1 if n > 0 else -1
		dir := Direction.Right if n > 0 else .Left
		if axis == 1 do dir = .Down if n > 0 else .Up
		for _ in 0..<abs(n) {
			set_facing(id, dir)
			if !wait_tween(tween_to_tile(id, entity_tile(id) + step, seconds_per_tile), loc) do return false
		}
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
