package game

// The map, its doors and the player come from the generated level code and
// enter_level; Cave adds its fires, which block the way.
init_cave_main :: proc() {
	play_music(.None)
	spawn_entity({name = "fire 0", tile = CAVE_MAIN_FIRE_0, sprite = create_sprite_state(.Fire, play = true)})
	spawn_entity({name = "fire 1", tile = CAVE_MAIN_FIRE_1, sprite = create_sprite_state(.Fire, play = true)})
	spawn_entity({name = "fire 2", tile = CAVE_MAIN_FIRE_2, sprite = create_sprite_state(.Fire, play = true)})
	spawn_entity({name = "fire 3", tile = CAVE_MAIN_FIRE_3, sprite = create_sprite_state(.Fire, play = true)})
}
