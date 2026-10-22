package game

import "../rules"

// Unqualified names for the rules package's data, for level code, scripts and
// the generated level code (process_tiled.py).
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
