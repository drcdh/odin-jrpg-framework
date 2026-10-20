package engine

import "core:math"

// World units are native pixels; the camera zooms them up.
TILE_SIZE :: 16
ZOOM      :: 4

Tile :: [2]i32

// Down is the zero value, so new entities face the camera.
Direction :: enum u8 {
	Down,
	Up,
	Left,
	Right,
}

dir_vec :: proc(d: Direction) -> Tile {
	switch d {
	case .Down:  return {0, 1}
	case .Up:    return {0, -1}
	case .Left:  return {-1, 0}
	case .Right: return {1, 0}
	}
	return {}
}

dir_opposite :: proc(d: Direction) -> Direction {
	switch d {
	case .Down:  return .Up
	case .Up:    return .Down
	case .Left:  return .Right
	case .Right: return .Left
	}
	return d
}

// Center of a tile in world pixels; sprites use a centered origin.
tile_center :: proc(t: Tile) -> [2]f32 {
	return {f32(t.x), f32(t.y)} * TILE_SIZE + TILE_SIZE / 2
}

world_to_tile :: proc(p: [2]f32) -> Tile {
	return {i32(math.floor(p.x / TILE_SIZE)), i32(math.floor(p.y / TILE_SIZE))}
}
