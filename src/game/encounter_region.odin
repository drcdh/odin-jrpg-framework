package game

import "core:log"
import "core:math/rand"
import rl "vendor:raylib"

encounter_region_data: struct { // TODO: needs to be saved with other game data
	region: Maybe(Encounter_Region),
	s: u8, // steps taken already
}

reset_encounter_step_counter :: proc() {
	log.infof("resetting encounter step counter, was %d", encounter_region_data.s)
	encounter_region_data.s = 0
}

random_encounter: struct { // just some global space for scripts to read
	background: Maybe(Battle_Background),
	encounter: Encounter_Name,
}

try_random_encounter :: proc(level: Level, tile: Tile) {
	region := get_encounter_region(level, tile)
	log.debugf("inside encounter region %v", region)
	if enc_idx, ok := get_encounter(region).?; ok {
		log.infof("starting random encounter %d", enc_idx)
		random_encounter = {region_backgrounds[region], enc_idx}
		spawn(proc(_: Entity_Id) {
			start_encounter(random_encounter.encounter, random_encounter.background)
			wait_battle()
			pause(2)
			reset_encounter_step_counter()
		})
	} else {
		log.debugf("no random encounter, this time...")
	}
}

enc_p :: proc(p0, dp: f32, s0, s: u8) -> f32 {
	if s < s0 {
		return 0
	}
	return p0 + dp * f32(max(0, s - s0))
}

enc_roll :: proc(p0, dp: f32, s0, s: u8) -> bool {
	p := enc_p(p0, dp, s0, s)
	roll := rand.float32()
	v := roll < p
	log.debugf("Rolled %.2f for encounter: prob = %.2f + %.2f * max(0, %d - %d) = %.2f --> %s", roll, p0, dp, s, s0, p, v ? "HIT" : "MISS")
	return v
}

get_encounter :: proc(encounter_region: Encounter_Region) -> (enc: Maybe(Encounter_Name) = nil) {
	if moogle_charm {return}

	if encounter_region != encounter_region_data.region {
		log.infof("Changing encounter region from %s to %s. Resetting step count from %d to zero.", encounter_region_data.region, encounter_region, encounter_region_data.s)
		encounter_region_data.region = encounter_region
		encounter_region_data.s = 0
	}

	switch encounter_region {
	case .None:
	case .Overworld_Grass_A:
		if enc_roll(0, .1, 5, encounter_region_data.s) {
			encs := [?]Encounter_Name{.Pr_Slimes_1, .Pr_Slimes_2}
			enc = rand.choice(encs[:])
		}
	case .Overworld_Grass_B:
		if enc_roll(0, .1, 10, encounter_region_data.s) {
			encs := [?]Encounter_Name{.Pr_Slimes_1, .Pr_Slimes_2, .Pr_Slimes_3, .Pr_Slimes_4}
			enc = rand.choice(encs[:])
		}
	}
	encounter_region_data.s += 1
	return
}

tile_in_rect :: proc(tile: Tile, rect: rl.Rectangle) -> bool {
	return rl.CheckCollisionPointRec({f32(tile.x), f32(tile.y)}, rect)
}
