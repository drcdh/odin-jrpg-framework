package game

import "core:fmt"
import "core:time"

SAVES_ROWS :: 3
TITLE_HEIGHT :: 2

// The height of a save slot in UI tiles.
SLOT_HEIGHT :: (VIEW_TILES_H - TITLE_HEIGHT) / SAVES_ROWS

draw_metadata :: proc(save_idx, r: int) {
	md := metadata[save_idx]
	j0 := f32(TITLE_HEIGHT + r * SLOT_HEIGHT)
	// draw_text(1, j0 + .5, fmt.ctprintf("%s", md.name))
	// draw_text(1, j0 + 1.25, fmt.ctprintf("Lvl %d", md.level))
	draw_text(1, j0 + 1.75, fmt.ctprintf("T. % 6d", md.time))
	draw_text(1, j0 + 2.25, fmt.ctprintf("S. % 6d", md.steps))

	t := time.from_nanoseconds(md.time_saved)
	date_buf: [time.MIN_YYYY_DATE_LEN]u8
	time_buf: [time.MIN_HMS_LEN]u8
	draw_text(
		1,
		j0 + 3,
		fmt.ctprintf(
			"%s %s %s",
			time.to_string_yyyy_mm_dd(t, date_buf[:]),
			time.time_to_string_hms(t, time_buf[:]),
			md.filepath,
		),
	)

	// party_idx := 0
	// for pc_idx in 0 ..< NUM_PC {
	// 	if md.party_membership[pc_idx] {
	// 		draw_sprite(create_pc_sprite_state(pc_idx), tile_to_pixel(6.5 + 1.5 * f32(party_idx), j0 + 1))
	// 		party_idx += 1
	// 	}
	// }
}
