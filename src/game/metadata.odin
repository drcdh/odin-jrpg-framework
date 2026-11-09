package game

import "core:log"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

Metadata :: struct {
	filepath:         string,
	level:            int,
	name:             string,
	party_health:     [NUM_PC]Stat,
	party_membership: [NUM_PC]bool,
	party_statuses:   [NUM_PC]Statuses,
	steps:            u32,
	time:             u32,
	time_loaded:      i64,
	time_saved:       i64,
	texture:          rl.RenderTexture, // the slot, drawn once by metadata_load
}

metadata: [dynamic]Metadata

metadata_clear :: proc() {
	for md in metadata {
		if md.texture.id != 0 do rl.UnloadRenderTexture(md.texture)
		delete(md.filepath)
		delete(md.name)
	}
	clear(&metadata)
}

// Reads the summaries of the save files in SAVE_DIR and draws each one's slot
// into its texture (so it needs a window). With no SAVE_DIR (no
// saves yet) or an unreadable one, the list is empty.
metadata_load :: proc() {
	metadata_clear()
	if !os.exists(SAVE_DIR) do return

	f, open_err := os.open(SAVE_DIR)
	if open_err != nil {
		log.errorf("Could not open directory '%s' for reading: %v", SAVE_DIR, open_err)
		return
	}
	defer os.close(f)

	fis: []os.File_Info
	defer os.file_info_slice_delete(fis, context.allocator)

	read_err: os.Error
	fis, read_err = os.read_dir(f, -1, context.allocator)
	if read_err != nil {
		log.errorf("Could not read directory '%s': %v", SAVE_DIR, read_err)
		return
	}

	log.debugf("Current working directory %v contains:", SAVE_DIR)

	for fi in fis {
		if fi.type == .Directory {
			log.debugf("%v (directory)", fi.name)
		} else {
			log.debugf("%v (%M)", fi.name, fi.size)
			d, ok := read_saved_game_data(fi.name)
			if !ok do continue
			party_health: [NUM_PC]Stat
			party_statuses: [NUM_PC]Statuses
			for c, i in d.party_data {
				party_health[i] = c.health
				party_statuses[i] = c.statuses
			}
			md := Metadata {
				filepath         = strings.clone(fi.name),
				level            = d.party_data[0].level,
				name             = strings.clone(d.party_data[0].name),
				party_health     = party_health,
				party_statuses   = party_statuses,
				party_membership = d.game_data.party_membership,
				steps            = d.game_data.steps,
				time             = d.game_data.time,
				// time_loaded      = d.save_data.time_loaded,
				time_saved       = d.time_saved,
			}
			md.texture = rl.LoadRenderTexture(i32(16 * TILE_SIZE), i32(SLOT_HEIGHT * TILE_SIZE))
			rl.BeginTextureMode(md.texture)
			draw_pane(0, 0, 16, SLOT_HEIGHT)
			draw_metadata(md)
			rl.EndTextureMode()
			append(&metadata, md)
		}
	}
}

metadata_unload :: proc() {
	metadata_clear()
	delete(metadata)
	metadata = nil
}
