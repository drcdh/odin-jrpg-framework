package game

pause_battle :: proc(paused := true) {
	battle.paused = paused
}

// This procedure blocks
process_skill_play_2 :: proc() {
	pause_battle(); defer pause_battle(false)
	skills[battle.skill_play.skill].procedure() // blocks
}
