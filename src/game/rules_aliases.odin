package game

import "../rules"

Level       :: rules.Level
Chest_Datum :: rules.Chest_Datum
Bool_Datum  :: rules.Bool_Datum
Int_Datum   :: rules.Int_Datum

get_game_data  :: rules.get_game_data
set_game_data  :: rules.set_game_data
init_new_game  :: rules.init_new_game
have_money     :: rules.have_money
inc_money      :: rules.inc_money
dec_money      :: rules.dec_money

quest_stage_between :: rules.quest_stage_between
quest_stage_current :: rules.quest_stage_current
quest_stage_passed  :: rules.quest_stage_passed
quest_stage_reached :: rules.quest_stage_reached

heal_party :: rules.heal_party
