package content

import "../game"

// Unqualified names for the game data that content and the generated level
// code (process_tiled.py) use.
Level       :: game.Level
Chest_Datum :: game.Chest_Datum
Bool_Datum  :: game.Bool_Datum
Int_Datum   :: game.Int_Datum

get_game_data  :: game.get_game_data
set_game_data  :: game.set_game_data
init_new_game  :: game.init_new_game
have_money     :: game.have_money
inc_money      :: game.inc_money
dec_money      :: game.dec_money
