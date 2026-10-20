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
	textures:        [dynamic]rl.Texture2D,
	clock:           Clock,
	camera:          rl.Camera2D,
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
	world.textures        = make([dynamic]rl.Texture2D, allocator)
	world.clock.time_scale = 1
	world.camera.zoom = ZOOM
}

// Cancels and reaps all scripts, then frees everything. Call before rl.CloseWindow.
shutdown :: proc() {
	scripts_shutdown()
	for tex in world.textures do rl.UnloadTexture(tex)
	delete(world.textures)
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
	entities_flush_destroyed()
}

player     :: proc() -> Entity_Id { return world.player }
camera     :: proc() -> rl.Camera2D { return world.camera }
set_player :: proc(id: Entity_Id) { world.player = id }

toggle_debug :: proc() { world.debug_overlay = !world.debug_overlay }
