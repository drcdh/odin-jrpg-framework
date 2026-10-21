package engine

import hm "core:container/handle_map"
import "core:math"
import "core:math/ease"
import rl "vendor:raylib"

Ease     :: ease.Ease
Tween_Id :: distinct hm.Handle32

// Tweenable entity properties. Values travel as [4]f32 lanes, so one code path
// covers scalars, vectors and colors; unused lanes are ignored.
Property :: enum u8 {
	Pos,
	Pos_X,
	Pos_Y,
	Scale,
	Scale_X,
	Scale_Y,
	Rotation,
	Tint,
	Alpha,
}

Entity_Prop :: struct {
	entity: Entity_Id,
	prop:   Property,
}

// ^f32 is an escape hatch for values outside entities (camera zoom, UI);
// the caller must keep the pointee alive for the tween's lifetime.
Tween_Target :: union {
	Entity_Prop,
	^f32,
}

Tween_Mode :: enum u8 {
	Once,      // finishes at `to` and is removed
	Loop,      // restarts from `from`; never finishes
	Ping_Pong, // goes back and forth; never finishes
}

Tween :: struct {
	handle:   Tween_Id,
	target:   Tween_Target,
	from, to: [4]f32,
	duration: f32,
	delay:    f32,
	time:     f32, // seconds since creation, including delay
	easing:   Ease,
	mode:     Tween_Mode,
	relative: bool, // `to` is an offset from the value at start
	started:  bool,
	arrive:   bool, // a tile move: finishing it fires the step triggers on the tile
}

// Starts a tween and returns immediately. `from` is captured when the tween
// actually starts (after `delay`). A tween already running on the same target is
// replaced. Returns `Tween_Id{}` if the target doesn't exist.
tween_start :: proc(
	target: Tween_Target,
	to: [4]f32,
	duration: f32,
	easing := Ease.Linear,
	mode := Tween_Mode.Once,
	delay: f32 = 0,
	relative := false,
) -> Tween_Id {
	if _, ok := target_get(target); !ok do return {}
	tween_cancel_target(target)
	h, err := hm.add(&world.tweens, Tween{
		target   = target,
		to       = to,
		duration = max(duration, 0),
		delay    = max(delay, 0),
		easing   = easing,
		mode     = mode,
		relative = relative,
	})
	assert(err == nil, "out of memory starting tween")
	return h
}

tween_to :: proc(id: Entity_Id, prop: Property, to: [4]f32, duration: f32, easing := Ease.Linear, mode := Tween_Mode.Once, delay: f32 = 0) -> Tween_Id {
	return tween_start(Entity_Prop{id, prop}, to, duration, easing, mode, delay)
}

tween_by :: proc(id: Entity_Id, prop: Property, delta: [4]f32, duration: f32, easing := Ease.Linear, mode := Tween_Mode.Once, delay: f32 = 0) -> Tween_Id {
	return tween_start(Entity_Prop{id, prop}, delta, duration, easing, mode, delay, relative = true)
}

tween_pos :: proc(id: Entity_Id, to: [2]f32, duration: f32, easing := Ease.Linear, mode := Tween_Mode.Once, delay: f32 = 0) -> Tween_Id {
	return tween_to(id, .Pos, {to.x, to.y, 0, 0}, duration, easing, mode, delay)
}

// Grid move: the logical tile changes immediately and the sprite slides after it.
tween_to_tile :: proc(id: Entity_Id, tile: Tile, duration: f32, easing := Ease.Linear) -> Tween_Id {
	e, ok := entity_get(id)
	if !ok do return {}
	e.tile = tile
	h := tween_pos(id, tile_center(tile), duration, easing)
	if t, has := hm.get(&world.tweens, h); has do t.arrive = true
	return h
}

tween_scale :: proc(id: Entity_Id, to: [2]f32, duration: f32, easing := Ease.Linear, mode := Tween_Mode.Once, delay: f32 = 0) -> Tween_Id {
	return tween_to(id, .Scale, {to.x, to.y, 0, 0}, duration, easing, mode, delay)
}

tween_rotation :: proc(id: Entity_Id, to: f32, duration: f32, easing := Ease.Linear, mode := Tween_Mode.Once, delay: f32 = 0) -> Tween_Id {
	return tween_to(id, .Rotation, {to, 0, 0, 0}, duration, easing, mode, delay)
}

tween_tint :: proc(id: Entity_Id, to: rl.Color, duration: f32, easing := Ease.Linear, mode := Tween_Mode.Once, delay: f32 = 0) -> Tween_Id {
	return tween_to(id, .Tint, color_to_lanes(to), duration, easing, mode, delay)
}

tween_alpha :: proc(id: Entity_Id, to: u8, duration: f32, easing := Ease.Linear, mode := Tween_Mode.Once, delay: f32 = 0) -> Tween_Id {
	return tween_to(id, .Alpha, {f32(to), 0, 0, 0}, duration, easing, mode, delay)
}

tween_f32 :: proc(ptr: ^f32, to: f32, duration: f32, easing := Ease.Linear, mode := Tween_Mode.Once, delay: f32 = 0) -> Tween_Id {
	return tween_start(ptr, {to, 0, 0, 0}, duration, easing, mode, delay)
}

// A tween is "done" once it finished, was cancelled or replaced, or lost its target.
tween_done :: proc(t: Tween_Id) -> bool {
	return !hm.is_valid(&world.tweens, t)
}

tween_cancel :: proc(t: Tween_Id) {
	hm.remove(&world.tweens, t)
}

tween_cancel_target :: proc(target: Tween_Target) {
	it := hm.iterator_make(&world.tweens)
	for t, h in hm.iterate(&it) {
		if target_equal(t.target, target) do hm.remove(&world.tweens, h)
	}
}

tweens_cancel_for_entity :: proc(id: Entity_Id) {
	it := hm.iterator_make(&world.tweens)
	for t, h in hm.iterate(&it) {
		if p, ok := t.target.(Entity_Prop); ok && p.entity == id do hm.remove(&world.tweens, h)
	}
}

// Tile moves that finish fire their step triggers after the loop, so the
// triggers may start tweens of their own.
tweens_update :: proc(dt: f32) {
	arrived := make([dynamic]Entity_Id, context.temp_allocator)
	it := hm.iterator_make(&world.tweens)
	for t, h in hm.iterate(&it) {
		if tween_step(t, dt) do continue
		if _, alive := target_get(t.target); alive && t.arrive {
			append(&arrived, t.target.(Entity_Prop).entity)
		}
		hm.remove(&world.tweens, h)
	}
	for id in arrived do entity_arrived(id)
}

// Advances one tween. Returns false once it is finished or its target is gone.
@(private)
tween_step :: proc(t: ^Tween, dt: f32) -> bool {
	current, ok := target_get(t.target)
	if !ok do return false

	t.time += dt
	local := t.time - t.delay
	if local < 0 do return true

	if !t.started {
		t.started = true
		t.from = current
		if t.relative do t.to += t.from
	}

	p: f32 = 1
	if t.duration > 0 do p = local / t.duration
	done := t.duration <= 0
	switch t.mode {
	case .Once:
		if p >= 1 {
			p = 1
			done = true
		}
	case .Loop:
		p -= math.floor(p)
	case .Ping_Pong:
		c := math.mod(p, 2)
		p = c if c <= 1 else 2 - c
	}

	k := ease.ease(t.easing, p)
	target_set(t.target, t.from + (t.to - t.from) * k)
	return !done
}

@(private)
target_equal :: proc(a, b: Tween_Target) -> bool {
	switch x in a {
	case Entity_Prop:
		y, ok := b.(Entity_Prop)
		return ok && x == y
	case ^f32:
		y, ok := b.(^f32)
		return ok && x == y
	}
	return false
}

@(private)
target_get :: proc(target: Tween_Target) -> (v: [4]f32, ok: bool) {
	switch t in target {
	case Entity_Prop:
		e := entity_get(t.entity) or_return
		return prop_get(e, t.prop), true
	case ^f32:
		return {t^, 0, 0, 0}, true
	}
	return
}

@(private)
target_set :: proc(target: Tween_Target, v: [4]f32) {
	switch t in target {
	case Entity_Prop:
		if e, ok := entity_get(t.entity); ok do prop_set(e, t.prop, v)
	case ^f32:
		t^ = v[0]
	}
}

prop_get :: proc(e: ^Entity, p: Property) -> [4]f32 {
	switch p {
	case .Pos:      return {e.pos.x, e.pos.y, 0, 0}
	case .Pos_X:    return {e.pos.x, 0, 0, 0}
	case .Pos_Y:    return {e.pos.y, 0, 0, 0}
	case .Scale:    return {e.sprite.scale.x, e.sprite.scale.y, 0, 0}
	case .Scale_X:  return {e.sprite.scale.x, 0, 0, 0}
	case .Scale_Y:  return {e.sprite.scale.y, 0, 0, 0}
	case .Rotation: return {e.sprite.rotation, 0, 0, 0}
	case .Tint:     return color_to_lanes(e.sprite.tint)
	case .Alpha:    return {f32(e.sprite.tint.a), 0, 0, 0}
	}
	return {}
}

prop_set :: proc(e: ^Entity, p: Property, v: [4]f32) {
	switch p {
	case .Pos:      e.pos = v.xy
	case .Pos_X:    e.pos.x = v.x
	case .Pos_Y:    e.pos.y = v.x
	case .Scale:    e.sprite.scale = v.xy
	case .Scale_X:  e.sprite.scale.x = v.x
	case .Scale_Y:  e.sprite.scale.y = v.x
	case .Rotation: e.sprite.rotation = v.x
	case .Tint:     e.sprite.tint = {lane_to_u8(v[0]), lane_to_u8(v[1]), lane_to_u8(v[2]), lane_to_u8(v[3])}
	case .Alpha:    e.sprite.tint.a = lane_to_u8(v.x)
	}
}

color_to_lanes :: proc(c: rl.Color) -> [4]f32 {
	return {f32(c.r), f32(c.g), f32(c.b), f32(c.a)}
}

// Clamped, because easings like Back and Elastic overshoot.
@(private)
lane_to_u8 :: proc(f: f32) -> u8 {
	return u8(clamp(math.round(f), 0, 255))
}
