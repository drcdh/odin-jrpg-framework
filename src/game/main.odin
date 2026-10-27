package game

import hm "core:container/handle_map"
import "core:log"
import "core:slice"
import rl "vendor:raylib"
import "../rules"

// general game state, relevant to battle and world modes
Game :: struct {
	audio:           Audio, // sound effects; see sound.odin
	battle:					 Battle,
	clock:           Clock,
	curtain:         f32, // 0 clear .. 1 black; see curtain_to
	dialogue:        Dialogue,
	entities:        hm.Dynamic_Handle_Map(Entity, Entity_Id),
	flash:           Screen_Flash,
	images:          hm.Dynamic_Handle_Map(Image, Image_Handle),
	input:           Input,
	pending_destroy: [dynamic]Entity_Id,
	script_order:    [dynamic]Script_Id, // spawn order; scripts resume in this order
	scripts:         hm.Dynamic_Handle_Map(Script, Script_Id),
	sprite_handles:  [Sprite_Name]Sprite_Handle, // unswapped sprites; zero = not loaded
	sprites:         hm.Dynamic_Handle_Map(Sprite, Sprite_Handle),
	swapped_sprites: map[Swap_Key]Sprite_Handle, // palette-swapped sprites
	tilesets:        [Tileset_Id]rl.Texture, // loaded on first use
	tweens:          hm.Dynamic_Handle_Map(Tween, Tween_Id),
	ui:              UI, // font, pane texture, icons; loaded only with a window
	world:					 World,
}

game: Game

init :: proc(allocator := context.allocator) {
	log.info("initializing game")
	hm.dynamic_init(&game.images, allocator)
	hm.dynamic_init(&game.scripts, allocator)
	hm.dynamic_init(&game.sprites, allocator)
	hm.dynamic_init(&game.tweens, allocator)
	game.pending_destroy = make([dynamic]Entity_Id, allocator)
	game.script_order    = make([dynamic]Script_Id, allocator)
	game.swapped_sprites = make(map[Swap_Key]Sprite_Handle, allocator)

	game.clock.time_scale = 1

	game.battle.camera.zoom = ZOOM
	game.world.camera.zoom = ZOOM

	dialogue_init(allocator)
	input_init()
	music_init()
	sounds_init(allocator)
	ui_init() // after the sprite maps: it creates the icon sprites
	world_init(allocator)
}

// Cancels and reaps all scripts, then frees everything. Call before rl.CloseWindow.
shutdown :: proc() {
	log.info("shutting down game")
	rules.destroy()

	hm.dynamic_destroy(&game.entities)
	hm.dynamic_destroy(&game.images)
	hm.dynamic_destroy(&game.scripts)
	hm.dynamic_destroy(&game.sprites)
	hm.dynamic_destroy(&game.tweens)
	delete(game.pending_destroy)
	delete(game.script_order)
	delete(game.swapped_sprites)

	it := hm.iterator_make(&game.images)
	for img, _ in hm.iterate(&it) do if img.texture.id != 0 do rl.UnloadTexture(img.texture)
	for tex in game.tilesets do if tex.id != 0 do rl.UnloadTexture(tex)

	scripts_shutdown()
	unload_map()

	dialogue_destroy()
	music_shutdown()
	sounds_destroy()
	ui_destroy()
	world_shutdown()
}

update :: proc() {
	clock_advance(rl.GetFrameTime())
	input_update(rl.GetFrameTime())

	if battle_staged() do encounter_init()
	if battle_active() {
		update_battle(game.clock.dt)
	} else {
		update_world()
	}

	debug_update()
	scripts_update()

	dialogue_update(game.clock.dt)
	sounds_update(game.clock.dt)
	sprites_update(game.clock.dt)
	tweens_update(game.clock.dt)
	ui_update(game.clock.raw_dt) // cursors animate while the menu pauses the world

	entities_flush_destroyed()
}

draw :: proc() {
	if battle_active() {
		draw_battle()
	} else {
		draw_world()
		draw_world_debug_hud()
	}
	draw_screen_effects()
	draw_dialogue()
	debug_draw()
}

draw_entities :: proc() {
	Draw_Item :: struct {
		layer: i32,
		y:     f32,
		e:     ^Entity,
	}
	items := make([dynamic]Draw_Item, 0, hm.len(game.entities), context.temp_allocator)
	it := hm.iterator_make(&game.entities)
	for e, _ in hm.iterate(&it) {
		if e.sprite.hidden do continue
		append(&items, Draw_Item{e.sprite.layer, e.pos.y, e})
	}
	slice.sort_by(items[:], proc(a, b: Draw_Item) -> bool {
		if a.layer != b.layer do return a.layer < b.layer
		return a.y < b.y
	})
	for item in items do draw_sprite(item.e.sprite, item.e.pos)
}

