package rules

import "core:fmt"
import "core:os"
import "core:strings"

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
