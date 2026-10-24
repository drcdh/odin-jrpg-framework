package game

import "core:math/ease"
import "core:math/linalg"
import rl "vendor:raylib"

// What the camera centers on: an entity it follows, or a fixed tile. nil
// leaves the camera where it is.
Camera_Focus :: union {
	Entity_Id,
	Tile,
}

// A pan from where the camera was to its focus, at `speed` tiles per second.
// It lerps towards the focus as it is each frame, so a pan onto a moving
// entity still lands on it.
Camera_Pan :: struct {
	from:     [2]f32,
	speed:    f32, // tiles per second; 0 = no pan
	easing:   Ease,
	elapsed:  f32,
	duration: f32, // set on the pan's first update, from the clamped distance; 0 until then
}

camera :: proc() -> rl.Camera2D { return world.camera }

// Follows `id`. With `speed` 0 the camera snaps to it; otherwise it pans
// there at `speed` tiles per second (game time), then follows. Immediate:
// usable from scripts; pan_camera_follow waits for the pan.
camera_follow :: proc(id: Entity_Id, speed: f32 = 0, easing := Ease.Linear) {
	camera_focus_on(id, speed, easing)
}

// Fixes the camera on `tile`'s center: a snap with `speed` 0, otherwise a pan
// at `speed` tiles per second. See camera_follow.
camera_to_tile :: proc(tile: Tile, speed: f32 = 0, easing := Ease.Linear) {
	camera_focus_on(tile, speed, easing)
}

camera_panning :: proc() -> bool { return world.camera_pan.speed > 0 }

// The entity the camera follows (or is panning to), if any.
camera_followed :: proc() -> Entity_Id {
	id, _ := world.camera_focus.(Entity_Id)
	return id
}

@(private = "file")
camera_focus_on :: proc(focus: Camera_Focus, speed: f32, easing: Ease) {
	world.camera_focus = focus
	world.camera_pan = {}
	if speed > 0 do world.camera_pan = {from = world.camera.target, speed = speed, easing = easing}
}

// Centers the focus on a screen of `screen` pixels, panning if a pan is under
// way. In CLAMP mode the view stays inside the map, and a map smaller than the
// view is centered.
camera_update :: proc(screen: [2]f32) {
	world.camera.offset = screen / 2
	focus, ok := camera_focus_point()
	if !ok {
		world.camera_pan = {}
		return
	}
	focus = camera_clamp(focus, screen)

	pan := &world.camera_pan
	if pan.speed <= 0 {
		world.camera.target = focus
		return
	}
	if pan.duration == 0 {
		pan.duration = linalg.distance(pan.from, focus) / (pan.speed * TILE_SIZE)
	}
	pan.elapsed += world.clock.dt
	if pan.elapsed >= pan.duration {
		world.camera.target = focus
		world.camera_pan = {}
		return
	}
	k := ease.ease(pan.easing, pan.elapsed / pan.duration)
	world.camera.target = linalg.lerp(pan.from, focus, k)
}

@(private = "file")
camera_focus_point :: proc() -> ([2]f32, bool) {
	switch f in world.camera_focus {
	case Entity_Id:
		if e, ok := entity_get(f); ok do return e.pos, true
	case Tile:
		return tile_center(f), true
	}
	return {}, false
}

@(private = "file")
camera_clamp :: proc(p: [2]f32, screen: [2]f32) -> [2]f32 {
	if world.level_map.mode != .CLAMP do return p
	p := p
	half := screen / world.camera.zoom / 2
	size := map_pixel_size()
	for i in 0..<2 {
		if size[i] <= 2 * half[i] {
			p[i] = size[i] / 2
		} else {
			p[i] = clamp(p[i], half[i], size[i] - half[i])
		}
	}
	return p
}
