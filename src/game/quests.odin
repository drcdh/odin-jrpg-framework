package game

Two_Quest :: enum {
	None,
	Knocked,
	Joined,
}

Demo_Quest :: enum {
	None,
	Started,
	Got_Pass,
	Boss_Beaten,
	Done,
}

quest_stage_between :: proc(datum: Int_Datum, #any_int start, end: int) -> bool {
	// [start, end)
	d := get_game_data(datum)
	return d >= Int_Data_Type(start) && d < Int_Data_Type(end)
}

quest_stage_current :: proc(datum: Int_Datum, #any_int stage: int) -> bool {
	return get_game_data(datum) == Int_Data_Type(stage)
}

quest_stage_passed :: proc(datum: Int_Datum, #any_int stage: int) -> bool {
	return get_game_data(datum) > Int_Data_Type(stage)
}

quest_stage_reached :: proc(datum: Int_Datum, #any_int stage: int) -> bool {
	return get_game_data(datum) >= Int_Data_Type(stage)
}
