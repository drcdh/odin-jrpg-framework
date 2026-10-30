package game

import rl "vendor:raylib"

@(rodata)
GUY_SHOP := Shop {
	inventory = {
		.Potion,
		.Super_Potion,
		.Antidote,
		.Poisonous_Mushroom,
		.Tea,
		.Boost_Donut,
		.Knife,
		.Sword,
		.Nail_Bat,
		.Basic_Wand,
		.Beef_Bracer,
		.Chump_Charm,
		.Speed_Ring,
	},
}

init_house_main :: proc() {
	play_music(.Town)

	spawn_entity(
		Entity {
			name = "Guy",
			sprite = walker_sprite(
				.Man_Ps,
				palette = {
					{rl.GetColor(0xeeeeeeff), rl.PINK},
					{rl.GetColor(0xddddddff), rl.BLUE},
					{rl.GetColor(0xccccccff), rl.BROWN},
					{rl.GetColor(0xbbbbbbff), rl.BEIGE},
				},
			),
			tile = HOUSE_MAIN_GUY_SPAWN,
			trigger = new_trigger(proc(self: Entity_Id) {
					say("Erm, hello, player.", entity_name(self))
					if get_game_data(Bool_Datum.Met_Dude) {
						say("Have you met Dude yet? Very good.")
					} else {
						say("Have you met Dude yet? No? Well!")
					}
					choice: int
					ok: bool
					if choice, ok = choose("Care to buy something?", {"Whatcha got?", "I'm good."}); !ok do return
					if choice == 0 do shop_enter(&GUY_SHOP)
				}),
		},
	)

	two := spawn_entity(
		{name = "Two", sprite = pc_sprite(1), tile = HOUSE_MAIN_DOOR, trigger = new_trigger(door_knock)},
	)
	set_visible(two, false)
}

@(private = "file")
door_knock :: proc(self: Entity_Id) {
	name := entity_name(self)
	pause(.5)
	play_sound(.Door_Knock)
	pause(1)
	if quest_stage_current(.Two_Quest, Two_Quest.None) {
		play_sound(.Door_Open)
		set_visible(self, true)
		say("We don't want any.", name)
		pause(.5)
		play_sound(.Door_Shut)
		set_visible(self, false)
		set_game_data(Int_Datum.Two_Quest, Two_Quest.Knocked)
	} else if quest_stage_current(.Two_Quest, Two_Quest.Knocked) {
		play_sound(.Door_Open)
		set_visible(self, true)
		say("Oh, alright. Let's go.", name)
		play_sound(.Fanfare)
		say("Player Two joined your party!")
		game_data.party_membership[1] = true
		set_visible(self, false)
		set_game_data(Int_Datum.Two_Quest, Two_Quest.Joined)
	} else {
		say("Nobody home.")
	}
}
