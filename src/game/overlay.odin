package game

import "core:fmt"
import rl "vendor:raylib"

@(private = "file")
CLOUDS_TINT :: rl.Color{255, 255, 255, 50} // FIXME: parameterize? make PNGs transparent?

@(private = "file")
OVERLAY_DIR :: "assets/overlays"

@(private = "file")
overlay_textures: [Overlay]rl.Texture

@(private = "file")
overlay_offset: [2]f32

init_overlays :: proc() {
	for overlay in Overlay {
		if overlay == .None do continue
		image := rl.LoadImage(fmt.ctprintf("%s/%s", OVERLAY_DIR, overlay_paths[overlay]))
		overlay_textures[overlay] = rl.LoadTextureFromImage(image)
		rl.UnloadImage(image)
	}
}

delete_overlays :: proc() {
	for overlay in Overlay {
		if overlay == .None do continue
		rl.UnloadTexture(overlay_textures[overlay])
	}
}

draw_overlay :: proc() {
	overlay := world.level_map.overlay
	if overlay == .None do return
	src := rl.Rectangle {
		overlay_offset.x + world.camera.target.x,
		overlay_offset.y + world.camera.target.y,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
	}
	dest := rl.Rectangle{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}
	rl.DrawTexturePro(overlay_textures[overlay], src, dest, {}, 0, CLOUDS_TINT)
}

update_overlay :: proc() {
	overlay := world.level_map.overlay
	if overlay == .None do return
	overlay_offset -= tile_to_pixel(.2, 0) * game.clock.dt
}
