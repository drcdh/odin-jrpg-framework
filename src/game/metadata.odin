package game

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

import "../engine"

Metadata :: struct {
	filepath:         string,
	// level:            int,
	// name:             string,
	// party_membership: [NUM_PC]bool,
	steps:            u32,
	time:             u32,
	time_loaded:      i64,
	time_saved:       i64,
}

metadata: [dynamic]Metadata

metadata_clear :: proc() {
	for md in metadata {
		delete(md.filepath)
		// delete(md.name)
	}
	clear(&metadata)
}

metadata_load :: proc() {
	metadata_clear()

	f, open_err := os.open(SAVE_DIR)
	if open_err != nil {
		fmt.eprintfln("Could not open directory '%s' for reading: %v", SAVE_DIR, open_err)
		os.exit(1)
	}
	defer os.close(f)

	fis: []os.File_Info
	defer os.file_info_slice_delete(fis, context.allocator)

	read_err: os.Error
	fis, read_err = os.read_dir(f, -1, context.allocator)
	if read_err != nil {
		fmt.eprintfln("Could not read directory: %v", read_err)
		os.exit(2)
	}

	fmt.printfln("Current working directory %v contains:", SAVE_DIR)

	for fi in fis {
		if fi.type == .Directory {
			fmt.printfln("%v (directory)", fi.name)
		} else {
			fmt.printfln("%v (%M)", fi.name, fi.size)
			d, ok := read_saved_game_data(fi.name)
			if !ok do continue
			md := Metadata {
				filepath         = strings.clone(fi.name),
				// level            = d.character_data[0].level,
				// name             = strings.clone(d.character_data[0].name),
				// party_membership = d.game_data.party_membership,
				steps            = d.game_data.steps,
				time             = d.game_data.time,
				// time_loaded      = d.save_data.time_loaded,
				time_saved       = d.time_saved,
			}
			append(&metadata, md)
		}
	}
}

metadata_unload :: proc() {
	metadata_clear()
	delete(metadata)
}

SAVES_ROWS :: 3
TITLE_HEIGHT :: 2

// The height of a save slot in UI tiles; the view height is only known at run time.
slot_height :: proc() -> int {
	return (int(engine.view_tiles().y) - TITLE_HEIGHT) / SAVES_ROWS
}

draw_metadata :: proc(save_idx, r: int) {
	md := metadata[save_idx]
	j0 := f32(TITLE_HEIGHT + r * slot_height())
	// engine.draw_text(1, j0 + .5, fmt.ctprintf("%s", md.name))
	// engine.draw_text(1, j0 + 1.25, fmt.ctprintf("Lvl %d", md.level))
	engine.draw_text(1, j0 + 1.75, fmt.ctprintf("T. % 6d", md.time))
	engine.draw_text(1, j0 + 2.25, fmt.ctprintf("S. % 6d", md.steps))

	t := time.from_nanoseconds(md.time_saved)
	date_buf: [time.MIN_YYYY_DATE_LEN]u8
	time_buf: [time.MIN_HMS_LEN]u8
	engine.draw_text(
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
