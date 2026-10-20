package engine

import hm "core:container/handle_map"
import "core:slice"
import rl "vendor:raylib"

// Index+1 into world.textures. 0 means no texture: the sprite draws as a solid rectangle.
Texture_Id :: distinct u32

Sprite :: struct {
	texture:        Texture_Id,
	src:            rl.Rectangle, // texture region; without a texture only width/height matter
	origin:         [2]f32,       // pivot, normalized: {0.5, 0.5} is the center
	scale:          [2]f32,
	rotation:       f32,          // degrees
	tint:           rl.Color,
	flip_x, flip_y: bool,
	layer:          i32,          // lower layers draw first; ties sort by y
	hidden:         bool,
}

// Textures must be loaded on the main thread (it owns the GL context), never from a script.
texture_add :: proc(tex: rl.Texture2D) -> Texture_Id {
	append(&world.textures, tex)
	return Texture_Id(len(world.textures))
}

texture_get :: proc(id: Texture_Id) -> (rl.Texture2D, bool) {
	if id == 0 || int(id) > len(world.textures) do return {}, false
	return world.textures[id - 1], true
}

sprite_from_texture :: proc(id: Texture_Id, tint := rl.WHITE, layer: i32 = 0) -> Sprite {
	tex, _ := texture_get(id)
	return {
		texture = id,
		src     = {0, 0, f32(tex.width), f32(tex.height)},
		origin  = {0.5, 0.5},
		scale   = {1, 1},
		tint    = tint,
		layer   = layer,
	}
}

sprite_rect :: proc(size: [2]f32, tint := rl.WHITE, layer: i32 = 0) -> Sprite {
	return {
		src    = {0, 0, size.x, size.y},
		origin = {0.5, 0.5},
		scale  = {1, 1},
		tint   = tint,
		layer  = layer,
	}
}

draw_sprite :: proc(pos: [2]f32, s: Sprite) {
	w := abs(s.src.width * s.scale.x)
	h := abs(s.src.height * s.scale.y)
	dest   := rl.Rectangle{pos.x, pos.y, w, h}
	origin := rl.Vector2{s.origin.x * w, s.origin.y * h}

	if tex, ok := texture_get(s.texture); ok {
		src := s.src
		if s.flip_x != (s.scale.x < 0) do src.width  = -src.width
		if s.flip_y != (s.scale.y < 0) do src.height = -src.height
		rl.DrawTexturePro(tex, src, dest, origin, s.rotation, s.tint)
	} else {
		rl.DrawRectanglePro(dest, origin, s.rotation, s.tint)
	}
}

draw_world :: proc() {
	Draw_Item :: struct {
		layer: i32,
		y:     f32,
		e:     ^Entity,
	}
	items := make([dynamic]Draw_Item, 0, hm.len(world.entities), context.temp_allocator)
	it := hm.iterator_make(&world.entities)
	for e, _ in hm.iterate(&it) {
		if e.sprite.hidden do continue
		append(&items, Draw_Item{e.sprite.layer, e.pos.y, e})
	}
	slice.sort_by(items[:], proc(a, b: Draw_Item) -> bool {
		if a.layer != b.layer do return a.layer < b.layer
		return a.y < b.y
	})
	for item in items do draw_sprite(item.e.pos, item.e.sprite)
}
