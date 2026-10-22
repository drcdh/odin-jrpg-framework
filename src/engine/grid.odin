package engine

import "core:math"

// World units are native pixels; the camera zooms them up.
TILE_SIZE :: 16
ZOOM      :: 4

// The screen shows VIEW_TILES_W x VIEW_TILES_H tiles, so the window is
// 1024x896. UI layouts (panes, menus) are in these tiles too (text.odin).
VIEW_TILES_W  :: 16
VIEW_TILES_H  :: 14
WINDOW_WIDTH  :: VIEW_TILES_W * TILE_SIZE * ZOOM
WINDOW_HEIGHT :: VIEW_TILES_H * TILE_SIZE * ZOOM

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

tile_to_pixel_Tile :: proc(t: Tile) -> [2]f32 {
	return {f32(t.x) * TILE_SIZE, f32(t.y) * TILE_SIZE}
}

tile_to_pixel_int_int :: proc(i, j: int) -> [2]f32 {
	return {f32(i) * TILE_SIZE, f32(j) * TILE_SIZE}
}

tile_to_pixel_f32_int :: proc(i: f32, j: int) -> [2]f32 {
	return {i * TILE_SIZE, f32(j) * TILE_SIZE}
}

tile_to_pixel_int_f32 :: proc(i: int, j: f32) -> [2]f32 {
	return {f32(i) * TILE_SIZE, j * TILE_SIZE}
}

tile_to_pixel_f32_f32 :: proc(i, j: f32) -> [2]f32 {
	return {i * TILE_SIZE, j * TILE_SIZE}
}

tile_to_pixel :: proc {
	tile_to_pixel_Tile,
	tile_to_pixel_int_int,
	tile_to_pixel_f32_int,
	tile_to_pixel_int_f32,
	tile_to_pixel_f32_f32,
}

world_to_tile :: proc(p: [2]f32) -> Tile {
	return {i32(math.floor(p.x / TILE_SIZE)), i32(math.floor(p.y / TILE_SIZE))}
}
