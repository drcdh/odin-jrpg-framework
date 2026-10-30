package game

import "core:math/ease"
import "core:math/linalg"
import rl "vendor:raylib"

Camera_Focus :: union {
	Entity_Id,
	Tile,
}

Camera_Pan :: struct {
	duration: f32, // set on the pan's first update, from the clamped distance; 0 until then
	easing:   Ease,
	elapsed:  f32,
	from:     [2]f32,
	speed:    f32, // tiles per second; 0 = no pan
}

Camera :: struct {
	using camera: rl.Camera2D,
	focus:  Camera_Focus,
	pan:    Camera_Pan,
}

camera :: proc() -> rl.Camera2D { return world.camera.camera }

camera_follow :: proc(id: Entity_Id, speed: f32 = 0, easing := Ease.Linear) {
	camera_focus_on(id, speed, easing)
}

camera_to_tile :: proc(tile: Tile, speed: f32 = 0, easing := Ease.Linear) {
	camera_focus_on(tile, speed, easing)
}

camera_panning :: proc() -> bool { return world.camera.pan.speed > 0 }

camera_followed :: proc() -> (Entity_Id, bool) #optional_ok {
	return world.camera.focus.(Entity_Id)
}

@(private = "file")
camera_focus_on :: proc(focus: Camera_Focus, speed: f32, easing: Ease) {
	world.camera.focus = focus
	world.camera.pan = {} if speed <= 0 else {from = world.camera.target, speed = speed, easing = easing}
}

camera_update :: proc() {
	world.camera.offset = [2]f32{WINDOW_WIDTH, WINDOW_HEIGHT} / 2
	focus, ok := camera_focus_point()
	if !ok {
		world.camera.pan = {}
		return
	}
	focus = camera_clamp(focus)

	pan := &world.camera.pan
	if pan.speed <= 0 {
		world.camera.target = focus
		return
	}
	if pan.duration == 0 {
		pan.duration = linalg.distance(pan.from, focus) / (pan.speed * TILE_SIZE)
	}
	pan.elapsed += game.clock.dt
	if pan.elapsed >= pan.duration {
		world.camera.target = focus
		world.camera.pan = {}
		return
	}
	k := ease.ease(pan.easing, pan.elapsed / pan.duration)
	world.camera.target = linalg.lerp(pan.from, focus, k)
}

@(private = "file")
camera_focus_point :: proc() -> ([2]f32, bool) {
	switch f in world.camera.focus {
	case Entity_Id:
		if e, ok := entity_get(f); ok do return e.pos, true
	case Tile:
		return tile_center(f), true
	}
	return {}, false
}

@(private = "file")
camera_clamp :: proc(p: [2]f32) -> [2]f32 {
	if world.level_map.mode != .CLAMP do return p
	p := p
	half := [2]f32{WINDOW_WIDTH, WINDOW_HEIGHT} / 2
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
