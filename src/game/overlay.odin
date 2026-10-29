package game

// import hm "core:container/handle_map"
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

@(private = "file")
darkness_texture: rl.RenderTexture

darkness: u8

init_darkness :: proc() {
	darkness_texture = rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
}

delete_darkness :: proc() {
	rl.UnloadRenderTexture(darkness_texture)
}

// draw_darkness :: proc() {
// 	if darkness > 0 {
// 		rl.BeginTextureMode(darkness_texture)
// 		rl.ClearBackground(rl.BLANK)
// 		it := hm.iterator_make(&world_entities.entities)
// 		for e, _ in hm.iterate(&it) {
// 			if !e.disabled && e.light > 0 {
// 				pos := get_entity_pixel(e^) - world.camera + TILE_SIZE / 2
// 				radius := f32(e.light) * TILE_SIZE
// 				rl.DrawCircleV(pos, radius, rl.WHITE)
// 			}
// 		}
// 		rl.BeginBlendMode(.SUBTRACT_COLORS)
// 		rl.DrawRectangleV({0, 0}, {WINDOW_WIDTH, WINDOW_HEIGHT}, rl.BLACK)
// 		rl.EndBlendMode()
// 		rl.EndTextureMode()
// 	}
// 	rect := rl.Rectangle{0, 0, WINDOW_WIDTH, -WINDOW_HEIGHT}
// 	rl.DrawTexturePro(darkness_texture.texture, rect, rect, {}, 0, {255, 255, 255, darkness})
// }
