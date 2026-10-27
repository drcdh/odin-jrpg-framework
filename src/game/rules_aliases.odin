package game

import "../rules"

// types
Level            :: rules.Level
Bool_Datum       :: rules.Bool_Datum
Chest_Datum      :: rules.Chest_Datum
Int_Datum        :: rules.Int_Datum
Stat_Name        :: rules.Stat_Name
Target_Selection :: rules.Target_Selection
Target_Type      :: rules.Target_Type
Target_One_Ally :: rules.Target_One_Ally
Target_One_Baddy :: rules.Target_One_Baddy
Target_All_Allies :: rules.Target_All_Allies
Target_All_Baddies :: rules.Target_All_Baddies
Target_All_Combatants :: rules.Target_All_Combatants
Consumable :: rules.Consumable
Encounter_Name :: rules.Encounter_Name

// helpers
get_game_data  :: rules.get_game_data
set_game_data  :: rules.set_game_data
init_new_game  :: rules.init_new_game
have_money     :: rules.have_money
inc_money      :: rules.inc_money
dec_money      :: rules.dec_money
heal_party     :: rules.heal_party
get_stat       :: rules.get_stat

// quest helpers
quest_stage_between :: rules.quest_stage_between
quest_stage_current :: rules.quest_stage_current
quest_stage_passed  :: rules.quest_stage_passed
quest_stage_reached :: rules.quest_stage_reached

// constants
CHARGE_MAX :: rules.CHARGE_MAX
BADDY_TEAM :: rules.BADDY_TEAM
PLAYER_TEAM :: rules.PLAYER_TEAM
MAX_ENCOUNTER_SIZE :: rules.MAX_ENCOUNTER_SIZE
