package game

import hm "core:container/handle_map"
import "core:log"
import "core:slice"
import rl "vendor:raylib"

// general game system stuff
Game :: struct {
	audio:           Audio, // sound effects; see sound.odin
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
}

game: Game

texture: rl.RenderTexture

init :: proc(allocator := context.allocator) {
	log.info("initializing game")
	hm.dynamic_init(&game.images, allocator)
	hm.dynamic_init(&game.scripts, allocator)
	hm.dynamic_init(&game.sprites, allocator)
	hm.dynamic_init(&game.tweens, allocator)
	game.pending_destroy = make([dynamic]Entity_Id, allocator)
	game.script_order    = make([dynamic]Script_Id, allocator)
	game.swapped_sprites = make(map[Swap_Key]Sprite_Handle, allocator)

	game.clock = {time_scale = 1}

	// TODO: use #load, preload (as here) at runtime, or lazy-load
	for bt in baddy_templates {
		preload_sprite(bt.texture)
	}
	for skill in skills {
		preload_sprite(skill.animation)
	}

	dialogue_init(allocator)
	input_init()
	music_init()
	sounds_init(allocator)
	ui_init() // after the sprite maps: it creates the icon sprites
	world_init(allocator)

	if rl.IsWindowReady() do texture = rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
}

// Cancels and reaps all scripts, then frees everything. Call before rl.CloseWindow.
shutdown :: proc() {
	log.info("shutting down game")
	scripts_shutdown()
	unload_map()

	dialogue_destroy()
	music_shutdown()
	sounds_destroy()
	ui_destroy()

	it := hm.iterator_make(&game.images)
	for img, _ in hm.iterate(&it) do if img.texture.id != 0 do rl.UnloadTexture(img.texture)
	for tex in game.tilesets do if tex.id != 0 do rl.UnloadTexture(tex)
	if texture.id != 0 do rl.UnloadRenderTexture(texture)
	texture = {}

	destroy()

	// Must be last: everything above may still look things up in these.
	hm.dynamic_destroy(&game.entities)
	hm.dynamic_destroy(&game.images)
	hm.dynamic_destroy(&game.scripts)
	hm.dynamic_destroy(&game.sprites)
	hm.dynamic_destroy(&game.tweens)
	delete(game.pending_destroy)
	delete(game.script_order)
	delete(game.swapped_sprites)

	world_shutdown()
	game = {} // a later init starts clean
}

// frame_dt is the real time since the last frame; the entrypoint passes
// rl.GetFrameTime. Call after input_update, which the entrypoint does so tests
// can set input themselves.
update :: proc(frame_dt: f32) {
	clock_advance(frame_dt)

	if battle_active() {
		update_battle(game.clock.dt)
	} else {
		update_world()
	}

	debug_update()
	tweens_update(game.clock.dt)
	scripts_update()

	dialogue_update(game.clock.dt)
	sounds_update(game.clock.dt)
	sprites_update(game.clock.dt)
	ui_update(game.clock.raw_dt) // cursors animate while the menu pauses the world

	if !battle_active() do camera_update()

	entities_flush_destroyed()
}

draw :: proc() {
	redraw_world_menu_content()

	rl.BeginTextureMode(texture)
	rl.ClearBackground({30, 30, 40, 255})
	if battle_active() {
		draw_battle()
	} else {
		draw_world()
	}
	draw_screen_effects()
	draw_dialogue()
	debug_draw()
	rl.EndTextureMode()
}

draw_entities :: proc(battle := false) {
	Draw_Item :: struct {
		layer: i32,
		y:     f32,
		e:     ^Entity,
	}
	items := make([dynamic]Draw_Item, 0, hm.len(game.entities), context.temp_allocator)
	it := hm.iterator_make(&game.entities)
	for e, _ in hm.iterate(&it) {
		if e.sprite.hidden || e.battle != battle do continue
		append(&items, Draw_Item{e.sprite.layer, e.pos.y, e})
	}
	slice.sort_by(items[:], proc(a, b: Draw_Item) -> bool {
		if a.layer != b.layer do return a.layer < b.layer
		return a.y < b.y
	})
	for item in items do draw_sprite(item.e.sprite, item.e.pos)
}

