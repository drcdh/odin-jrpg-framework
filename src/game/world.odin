package game

import hm "core:container/handle_map"
import rl "vendor:raylib"
import "../rules"

// All game state. Script threads touch it too, but only while the main
// thread is blocked waiting for them, so no locking is needed.
World :: struct {
	entities:        hm.Dynamic_Handle_Map(Entity, Entity_Id),
	tweens:          hm.Dynamic_Handle_Map(Tween, Tween_Id),
	scripts:         hm.Dynamic_Handle_Map(Script, Script_Id),
	script_order:    [dynamic]Script_Id, // spawn order; scripts resume in this order
	pending_destroy: [dynamic]Entity_Id,
	images:          hm.Dynamic_Handle_Map(Image, Image_Handle),
	sprites:         hm.Dynamic_Handle_Map(Sprite, Sprite_Handle),
	sprite_handles:  [Sprite_Name]Sprite_Handle, // unswapped sprites; zero = not loaded
	swapped_sprites: map[Swap_Key]Sprite_Handle, // palette-swapped sprites
	clock:           Clock,
	camera:          rl.Camera2D,
	camera_focus:    Camera_Focus, // what the camera centers on; see camera.odin
	camera_pan:      Camera_Pan,
	level_map:       Level_Map,
	tilesets:        [Tileset_Id]rl.Texture, // loaded on first use
	flash:           Screen_Flash,
	curtain:         f32, // 0 clear .. 1 black; see curtain_to
	dialogue:        Dialogue,
	audio:           Audio, // sound effects; see sound.odin
	input:           Input,
	ui:              UI, // font, pane texture, icons; loaded only with a window
	player:          Entity_Id,
	player_control:  Player_Control,
	levels:          Levels, // the current level and level changes
	debug_overlay:   bool,
}

world: World

init :: proc(allocator := context.allocator) {
	hm.dynamic_init(&world.entities, allocator)
	hm.dynamic_init(&world.tweens, allocator)
	hm.dynamic_init(&world.scripts, allocator)
	world.script_order    = make([dynamic]Script_Id, allocator)
	world.pending_destroy = make([dynamic]Entity_Id, allocator)
	hm.dynamic_init(&world.images, allocator)
	hm.dynamic_init(&world.sprites, allocator)
	world.swapped_sprites = make(map[Swap_Key]Sprite_Handle, allocator)
	world.clock.time_scale = 1
	world.camera.zoom = ZOOM
	input_init()
	ui_init() // after the sprite maps: it creates the icon sprites
	dialogue_init(allocator)
	sounds_init(allocator)
	music_init()
}

// Cancels and reaps all scripts, then frees everything. Call before rl.CloseWindow.
shutdown :: proc() {
	rules.destroy()
	scripts_shutdown()
	dialogue_destroy()
	music_shutdown()
	sounds_destroy()
	ui_destroy()
	it := hm.iterator_make(&world.images)
	for img, _ in hm.iterate(&it) do if img.texture.id != 0 do rl.UnloadTexture(img.texture)
	for tex in world.tilesets do if tex.id != 0 do rl.UnloadTexture(tex)
	unload_map()
	delete(world.swapped_sprites)
	hm.dynamic_destroy(&world.sprites)
	hm.dynamic_destroy(&world.images)
	delete(world.pending_destroy)
	delete(world.script_order)
	hm.dynamic_destroy(&world.scripts)
	hm.dynamic_destroy(&world.tweens)
	hm.dynamic_destroy(&world.entities)
	world = {}
}

// One simulation step, starting with the player's turn. Call after
// clock_advance and input_update.
update :: proc() {
	debug_update()
	player_update()
	tweens_update(world.clock.dt)
	scripts_update()
	if battle.active do update_battle(world.clock.dt)
	dialogue_update(world.clock.dt)
	sounds_update(world.clock.dt)
	world_menu_update()
	sprites_update(world.clock.dt)
	ui_update(world.clock.raw_dt) // cursors animate while the menu pauses the world
	camera_update({f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())})
	entities_flush_destroyed()
}

player     :: proc() -> Entity_Id { return world.player }
set_player :: proc(id: Entity_Id) { world.player = id }

toggle_debug :: proc() { world.debug_overlay = !world.debug_overlay }
