package engine

import hm "core:container/handle_map"
import rl "vendor:raylib"

// All engine state. Script threads touch it too, but only while the main
// thread is blocked waiting for them, so no locking is needed.
World :: struct {
	entities:        hm.Dynamic_Handle_Map(Entity, Entity_Id),
	tweens:          hm.Dynamic_Handle_Map(Tween, Tween_Id),
	scripts:         hm.Dynamic_Handle_Map(Script, Script_Id),
	script_order:    [dynamic]Script_Id, // spawn order; scripts resume in this order
	pending_destroy: [dynamic]Entity_Id,
	images:          hm.Dynamic_Handle_Map(Image, Image_Handle),
	sprites:         hm.Dynamic_Handle_Map(Sprite, Sprite_Handle),
	sprite_handles:  map[Sprite_Name]Sprite_Handle, // unswapped sprites, by name
	sprite_metadata: map[Sprite_Name]Sprite_Metadata,
	clock:           Clock,
	camera:          rl.Camera2D,
	flash:           Screen_Flash,
	dialogue:        Dialogue,
	player:          Entity_Id,
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
	world.sprite_handles  = make(map[Sprite_Name]Sprite_Handle, allocator)
	world.sprite_metadata = make(map[Sprite_Name]Sprite_Metadata, allocator)
	world.clock.time_scale = 1
	world.camera.zoom = ZOOM
}

// Cancels and reaps all scripts, then frees everything. Call before rl.CloseWindow.
shutdown :: proc() {
	scripts_shutdown()
	it := hm.iterator_make(&world.images)
	for img, _ in hm.iterate(&it) do if img.texture.id != 0 do rl.UnloadTexture(img.texture)
	delete(world.sprite_metadata)
	delete(world.sprite_handles)
	hm.dynamic_destroy(&world.sprites)
	hm.dynamic_destroy(&world.images)
	delete(world.pending_destroy)
	delete(world.script_order)
	hm.dynamic_destroy(&world.scripts)
	hm.dynamic_destroy(&world.tweens)
	hm.dynamic_destroy(&world.entities)
	world = {}
}

// One simulation step. Call after clock_advance and the game's own input/update code.
update :: proc() {
	tweens_update(world.clock.dt)
	scripts_update()
	sprites_update(world.clock.dt)
	entities_flush_destroyed()
}

player     :: proc() -> Entity_Id { return world.player }
camera     :: proc() -> rl.Camera2D { return world.camera }
set_player :: proc(id: Entity_Id) { world.player = id }

toggle_debug :: proc() { world.debug_overlay = !world.debug_overlay }
