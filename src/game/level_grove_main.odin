package game

import "../engine"

init_grove_main :: proc() {
	player := engine.spawn_entity({
		name   = "player",
		tile   = GROVE_MAIN_PLAYER_SPAWN_INTRO,
		sprite = character_sprite(PLAYER_BODY, layer = 1),
	})
	engine.set_player(player)

	dude := engine.spawn_entity({
		name   = "dude",
		tile   = GROVE_MAIN_DUDE_SPAWN_NOT_MET,
		sprite = character_sprite(),
	})
	engine.spawn(pace_dude_route_0, dude, "dude pace")
}

// Walks to the start of dude_route_0, then paces it forever. The route is a
// two-point polyline, so walk_route goes out and back.
pace_dude_route_0 :: proc(self: engine.Entity_Id) {
	STEP  :: 0.4
	PAUSE :: 0.25
	route := engine.map_route(GROVE_MAIN_DUDE_ROUTE_0)
	if !engine.walk_entity(self, route[0] - engine.entity_tile(self), STEP, PAUSE) do return
	for {
		engine.pause(PAUSE) or_break
		engine.walk_route(self, route, STEP, PAUSE) or_break
	}
}
