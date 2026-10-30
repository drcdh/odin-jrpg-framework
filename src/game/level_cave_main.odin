package game

@(private = "file")
DARKNESS :: 255

@(private = "file")
DIM_FACT :: 10

@(private = "file")
PLAYER_LIGHT_MAX :: 3

@(private = "file")
PLAYER_LIGHT_MIN :: 1

@(private = "file")
torch :: proc(_: Entity_Id) {
	set_light(player(), 3)
	darkness = 215
}

init_cave_main :: proc() {
	play_music(.Cave)
	spawn_entity({name = "fire 0", tile = CAVE_MAIN_FIRE_0, sprite = create_sprite_state(.Fire, play = true), trigger = new_trigger(torch)})
	spawn_entity({name = "fire 1", tile = CAVE_MAIN_FIRE_1, sprite = create_sprite_state(.Fire, play = true), trigger = new_trigger(torch)})
	spawn_entity({name = "fire 2", tile = CAVE_MAIN_FIRE_2, sprite = create_sprite_state(.Fire, play = true), trigger = new_trigger(torch)})
	spawn_entity({name = "fire 3", tile = CAVE_MAIN_FIRE_3, sprite = create_sprite_state(.Fire, play = true), trigger = new_trigger(torch)})

	set_light(player(), PLAYER_LIGHT_MAX)
	darkness = DARKNESS - PLAYER_LIGHT_MAX * DIM_FACT

	spawn(proc(_: Entity_Id) {
		say("Damn, it's dark in here!")
	})

	spawn(proc(_: Entity_Id) {
		PERIOD :: .1 // seconds
		dl := f32(PERIOD / DIM_FACT)
		pc := entity_get(player())
		for {
			if !pause(PERIOD) do break
			pc.light = max(1, pc.light - dl)
			darkness = u8(DARKNESS - pc.light * DIM_FACT)
		}
	}, name = "player light dimming")
}
