package game

import hm "core:container/handle_map"
import rl "vendor:raylib"

@(private = "file")
darkness_texture: rl.RenderTexture

darkness: u8

init_darkness :: proc() {
	darkness_texture = rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
}

delete_darkness :: proc() {
	rl.UnloadRenderTexture(darkness_texture)
}

draw_darkness :: proc() {
	src := rl.Rectangle{0, 0, WINDOW_WIDTH, -WINDOW_HEIGHT}
	dest := rl.Rectangle{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}
	rl.DrawTexturePro(darkness_texture.texture, src, dest, {}, 0, {255, 255, 255, darkness})
}

update_darkness :: proc() {
	if darkness == 0 do return
	rl.BeginTextureMode(darkness_texture)
	rl.ClearBackground(rl.BLANK)
	it := hm.iterator_make(&game.entities)
	for e, _ in hm.iterate(&it) {
		if e.light > 0 {
			pos := e.pos + world.camera.offset - world.camera.target
			radius := e.light * TILE_SIZE
			rl.DrawCircleV(pos, radius, rl.WHITE)
		}
	}
	rl.BeginBlendMode(.SUBTRACT_COLORS)
	rl.DrawRectangleV({0, 0}, {WINDOW_WIDTH, WINDOW_HEIGHT}, rl.BLACK)
	rl.EndBlendMode()
	rl.EndTextureMode()
}
