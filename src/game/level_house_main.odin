package game

import rl "vendor:raylib"

init_house_main :: proc() {
	play_music(.Town)

	spawn_entity(
		Entity {
			name = "Guy",
			sprite = walker_sprite(
				.Man_Ps,
				{
					{rl.GetColor(0xeeeeeeff), rl.PINK},
					{rl.GetColor(0xddddddff), rl.BLUE},
					{rl.GetColor(0xccccccff), rl.BROWN},
					{rl.GetColor(0xbbbbbbff), rl.BEIGE},
				},
			),
			tile = HOUSE_MAIN_GUY_SPAWN,
			trigger = new_trigger(proc(self: Entity_Id) {
					say("Erm, hello, player.", "Guy")
					if get_game_data(Bool_Datum.Met_Dude) {
						say("Have you met Dude yet? Very good.")
					} else {
						say("Have you met Dude yet? No? Well!")
					}
				}, autobusy = true, autoface = true),
		},
	)

	two := spawn_entity(
		{sprite = pc_sprite(1), tile = HOUSE_MAIN_DOOR, trigger = new_trigger(door_knock)},
	)
	set_visible(two, false)
}

@(private = "file")
door_knock :: proc(self: Entity_Id) {
	pause(.5)
	play_sound(.Door_Knock)
	pause(1)
	if quest_stage_current(.Two_Quest, Two_Quest.None) {
		play_sound(.Door_Open)
		set_visible(self, true)
		say("We don't want any.", "Two")
		pause(.5)
		play_sound(.Door_Shut)
		set_visible(self, false)
		set_game_data(Int_Datum.Two_Quest, Two_Quest.Knocked)
	} else if quest_stage_current(.Two_Quest, Two_Quest.Knocked) {
		play_sound(.Door_Open)
		set_visible(self, true)
		say("Oh, alright. Let's go.", "Two")
		play_sound(.Fanfare)
		say("Player Two joined your party!")
		game_data.party_membership[1] = true
		set_visible(self, false)
		set_game_data(Int_Datum.Two_Quest, Two_Quest.Joined)
	} else {
		say("Nobody home.")
	}
}
