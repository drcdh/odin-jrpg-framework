package game

import "core:fmt"
import rl "vendor:raylib"

BB_DIR :: "assets/battle_backgrounds"

bb_textures: [Battle_Background]rl.Texture

bb_init :: proc() {
	for bb in Battle_Background {
		if bb == .None do continue // TODO create debug image, like checker pattern
		bb_image := rl.LoadImage(fmt.ctprintf("%s/%s", BB_DIR, battle_background_paths[bb]))
		bb_textures[bb] = rl.LoadTextureFromImage(bb_image)
		rl.UnloadImage(bb_image)
	}
}

draw_bb :: proc(bb: Battle_Background) {
	if bb == .None do return
	texture := bb_textures[bb]
	w := f32(texture.width)
	h := f32(texture.height)
	dest := rl.Rectangle{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}
	tint :: rl.WHITE
	rl.DrawTexturePro(texture, {0, 0, w, h}, dest, {}, 0, tint)
}

@(rodata) // TODO: derive this from Tiled
region_backgrounds := [Encounter_Region]Maybe(Battle_Background) {
	.None = nil,
}
