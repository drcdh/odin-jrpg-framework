package game

import hm "core:container/handle_map"
import "core:fmt"
import "core:hash"
import "core:log"
import "core:slice"
import rl "vendor:raylib"

SPRITE_DIR :: "assets/sprites"

// Rows of a Tagged sheet. A sheet uses a subset, listed in its metadata.
Sprite_Tag :: enum {
	Left,
	Down,
	Right,
	Up,
	NodLeft,
	NodDown,
	NodRight,
	NodUp,
	Active,
	Inactive,
	Closed,
	Opened,
	Idle,
	Walk,
	Ready,
	LArm,
	RArm,
	Cast,
	Cheer,
	Hit,
	Kneeled,
	Downed,
	Surprised,
	BoundLeft,
	BoundRight,
	BoundUp,
	BoundDown,
}

Sprite_Type :: enum {
	Static, // one frame
	Anim,   // one row of num_frames[0] frames
	Tagged, // one row per tag, each with its own frame count
}

// `Sprite_Name` and the `sprite_metadata` table are generated into
// sprite_data.odin by src/build_tools/process_sprites.py from the Aseprite
// files in assets/sprites (build.sh runs it).

Pixel_Dim :: [2]f32

// Sheet layout: frames go left to right, tags (in `tags` order) top to bottom.
Sprite_Metadata :: struct {
	filename:   string,       // in SPRITE_DIR, without ".png"
	frame_size: Pixel_Dim,
	type:       Sprite_Type,
	tags:       []Sprite_Tag, // Tagged only; Aseprite tag names must match Sprite_Tag members
	num_frames: []u16,        // per tag; Anim uses [0]
	frame_t:    f32,          // milliseconds per frame
}

Image_Handle  :: distinct hm.Handle32
Sprite_Handle :: distinct hm.Handle32

Image :: struct {
	handle:  Image_Handle,
	texture: rl.Texture,
}

// A loaded sheet. Palette-swapped copies share the name (and metadata) but
// have their own image. `meta` is copied from sprite_metadata on load, so
// lookups don't go back to the table.
Sprite :: struct {
	handle: Sprite_Handle,
	name:   Sprite_Name,
	img_h:  Image_Handle,
	meta:   Sprite_Metadata,
}

Color_Swap :: struct {
	from, to: rl.Color,
}

Palette_Swap :: []Color_Swap

// When an entity's sprite animates (with `anim` on).
Anim_When :: enum u8 {
	Always, // all the time
	Moving, // only while the entity moves, one loop per tile (Entity.step_time); still, it holds frame 0 halfway through, so a stride is centered on the tile
	Never,  // not at all; the frame stays where it is
}

// Per-entity sprite: which sheet and frame, playback, and draw transforms.
Sprite_State :: struct {
	sprite:         Sprite_Handle,
	tag:            Sprite_Tag,
	frame:          u16,
	anim:           bool, // playing
	time:           f32,  // seconds into the current frame
	speed:          f32,  // playback speed factor
	follow_facing:  bool, // keep `tag` on the Left/Down/Right/Up row for the entity's facing
	anim_when:      Anim_When,

	tint:           rl.Color,
	origin:         [2]f32, // pivot, normalized: {0.5, 0.5} is the center
	scale:          [2]f32,
	rotation:       f32,    // degrees
	flip_x, flip_y: bool,
	layer:          i32,    // lower layers draw first; ties sort by y
	hidden:         bool,
}

// --- Registry and loading ---

// Cache key for a palette-swapped sprite: its name and a hash of the swaps.
Swap_Key :: struct {
	name:    Sprite_Name,
	palette: u64,
}

// Loads the sheet unless it's cached. Unswapped sprites are cached by name,
// palette-swapped ones by name and palette, so respawning the same character
// (say, on every level change) reuses its texture. Main thread only: it may
// upload a texture.
get_sprite_h :: proc(name: Sprite_Name, palette: Palette_Swap = {}) -> Sprite_Handle {
	if len(palette) == 0 {
		if h := game.sprite_handles[name]; hm.is_valid(&game.sprites, h) do return h
		h := load_sprite(name, palette)
		game.sprite_handles[name] = h
		return h
	}
	key := Swap_Key{name, hash.fnv64a(slice.to_bytes(palette))}
	if h, ok := game.swapped_sprites[key]; ok && hm.is_valid(&game.sprites, h) do return h
	h := load_sprite(name, palette)
	game.swapped_sprites[key] = h
	return h
}

// Load up front so scripts that switch sprites only ever hit the cache.
preload_sprite :: proc(name: Sprite_Name) {
	_ = get_sprite_h(name)
}

@(private)
load_sprite :: proc(name: Sprite_Name, palette: Palette_Swap) -> Sprite_Handle {
	if len(palette) > 0 {
		log.infof("loading sprite %v with palette swap %v", name, palette)
	} else {
		log.infof("loading sprite %v", name)
	}
	assert(!in_script(), "sprites must be loaded on the main thread (preload_sprite)")
	m := sprite_metadata[name]
	sprite := Sprite{name = name, meta = m}

	// Headless (tests, tools): a sprite record with no image, which draws nothing.
	if !rl.IsWindowReady() {
		h, err := hm.add(&game.sprites, sprite)
		assert(err == nil, "out of memory loading sprite")
		return h
	}

	img := rl.LoadImage(fmt.ctprintf("%s/%s.png", SPRITE_DIR, m.filename))
	defer rl.UnloadImage(img)
	if img.data == nil {
		log.errorf("could not load %s/%s.png for sprite %v (run process_sprites.py?)", SPRITE_DIR, m.filename, name)
	} else {
		for cs in palette do rl.ImageColorReplace(&img, cs.from, cs.to)
		sprite.img_h, _ = hm.add(&game.images, Image{texture = rl.LoadTextureFromImage(img)})
	}

	h, err := hm.add(&game.sprites, sprite)
	assert(err == nil, "out of memory loading sprite")
	return h
}

// --- Sprite_State ---

// Without a window (tests, headless tools) this returns a state with no sheet
// that draws nothing but still has its transforms.
create_sprite_state :: proc(
	name: Sprite_Name,
	tag: Maybe(Sprite_Tag) = nil,
	palette: Palette_Swap = {},
	tint := rl.WHITE,
	play := false,
	speed: f32 = 1,
	follow_facing := false,
	layer: i32 = 0,
	anim_when := Anim_When.Always,
) -> (s: Sprite_State) {
	s.tint = tint
	s.origin = {0.5, 0.5}
	s.scale = {1, 1}
	s.anim = play
	s.speed = speed
	s.follow_facing = follow_facing
	s.anim_when = anim_when
	s.layer = layer

	if !rl.IsWindowReady() {
		log.warnf("raylib not initialized; sprite state for %v has no sheet", name)
		return
	}
	s.sprite = get_sprite_h(name, palette)
	if m := sprite_metadata[name]; m.type == .Tagged && len(m.tags) > 0 {
		s.tag = tag.? or_else m.tags[0]
	}
	return
}

update_sprite :: proc(dt: f32, state: ^Sprite_State) -> (looped: bool) {
	m := state_metadata(state^) or_return
	if m.type == .Static || !state.anim do return false
	n := frame_count(m, state.tag)
	if n == 0 || m.frame_t <= 0 do return false

	state.time += dt * state.speed
	frame_t := m.frame_t / 1000
	if state.time >= frame_t {
		state.time -= frame_t
		state.frame = (state.frame + 1) %% n
		return state.frame == 0
	}
	return false
}

freeze_sprite :: proc(state: ^Sprite_State, frame: u16) {
	state.frame = frame
	state.anim = false
}

unfreeze_sprite :: proc(state: ^Sprite_State) {
	state.anim = true
}

play_sprite :: proc(state: ^Sprite_State, t: f32 = 0) {
	state.anim = true
	state.time = t
}

stop_sprite :: proc(state: ^Sprite_State) {
	state.anim = false
	state.frame = 0
	state.time = 0
}

get_sprite_tag :: proc(state: Sprite_State) -> Sprite_Tag {
	return state.tag
}

set_sprite_tag :: proc(state: ^Sprite_State, tag: Sprite_Tag, reset := true) {
	state.tag = tag
	if reset {
		state.anim = false
		state.frame = 0
		state.time = 0
	}
}

// Seconds for one pass through the current row (0 for Static).
animation_length :: proc(state: Sprite_State) -> f32 {
	m, ok := state_metadata(state)
	if !ok || m.type == .Static do return 0
	return f32(frame_count(m, state.tag)) * m.frame_t / 1000
}

direction_tag :: proc(d: Direction) -> Sprite_Tag {
	switch d {
	case .Down:  return .Down
	case .Up:    return .Up
	case .Left:  return .Left
	case .Right: return .Right
	}
	return .Down
}

// The inverse of direction_tag; tags that aren't directions give Down.
tag_direction :: proc(t: Sprite_Tag) -> Direction {
	#partial switch t {
	case .Up:    return .Up
	case .Left:  return .Left
	case .Right: return .Right
	}
	return .Down
}

// The frame to draw: column by frame, row by the tag's index in the sheet.
sprite_src :: proc(state: Sprite_State) -> rl.Rectangle {
	m, ok := state_metadata(state)
	if !ok do return {}
	row := 0
	if m.type == .Tagged do row, _ = tag_index(m.tags, state.tag)
	return {f32(state.frame) * m.frame_size.x, f32(row) * m.frame_size.y, m.frame_size.x, m.frame_size.y}
}

sprite_size_name :: proc(name: Sprite_Name) -> Pixel_Dim {
	return sprite_metadata[name].frame_size
}

sprite_size_state :: proc(state: Sprite_State) -> Pixel_Dim {
	m, _ := state_metadata(state)
	return m.frame_size
}

sprite_size :: proc {
	sprite_size_name,
	sprite_size_state,
}

// Advances every entity's animation (see Anim_When); facing-following
// sprites switch rows without restarting playback.
sprites_update :: proc(dt: f32) {
	it := hm.iterator_make(&game.entities)
	for e, _ in hm.iterate(&it) {
		s := &e.sprite
		if s.follow_facing {
			want := direction_tag(e.facing)
			if m, ok := state_metadata(s^); ok && want != s.tag {
				if _, has := tag_index(m.tags, want); has {
					s.tag = want
					if n := frame_count(m, want); n > 0 do s.frame %= n
				}
			}
		}
		switch s.anim_when {
		case .Always:
			update_sprite(dt, s)
		case .Moving:
			if e.pos == tile_center(e.tile) {
				// Frame 0 is the idle pose: start the next move halfway through it.
				s.frame, s.time = 0, 0
				if m, ok := state_metadata(s^); ok do s.time = m.frame_t / 1000 / 2
			} else if e.step_time > 0 {
				update_sprite(dt * animation_length(s^) / e.step_time, s) // one loop per tile
			} else {
				update_sprite(dt, s)
			}
		case .Never:
		}
	}
}

// --- Drawing ---

draw_sprite :: proc(state: Sprite_State, pos: [2]f32, tint := rl.WHITE) {
	sprite := hm.get(&game.sprites, state.sprite) or_else nil
	if sprite == nil do return
	image := hm.get(&game.images, sprite.img_h) or_else nil
	if image == nil || image.texture.id == 0 do return

	src := sprite_src(state)
	w := abs(src.width * state.scale.x)
	h := abs(src.height * state.scale.y)
	dest   := rl.Rectangle{pos.x, pos.y, w, h}
	origin := rl.Vector2{state.origin.x * w, state.origin.y * h}
	if state.flip_x != (state.scale.x < 0) do src.width  = -src.width
	if state.flip_y != (state.scale.y < 0) do src.height = -src.height
	rl.DrawTexturePro(image.texture, src, dest, origin, state.rotation, rl.ColorTint(state.tint, tint))
}

// --- Helpers ---

@(private)
state_metadata :: proc(state: Sprite_State) -> (Sprite_Metadata, bool) {
	sprite, ok := hm.get(&game.sprites, state.sprite)
	if !ok do return {}, false
	return sprite.meta, true
}

@(private)
tag_index :: proc(tags: []Sprite_Tag, tag: Sprite_Tag) -> (int, bool) {
	for t, i in tags do if t == tag do return i, true
	return 0, false
}

@(private)
frame_count :: proc(m: Sprite_Metadata, tag: Sprite_Tag) -> u16 {
	i := 0
	if m.type == .Tagged do i, _ = tag_index(m.tags, tag)
	return m.num_frames[i] if i < len(m.num_frames) else 0
}
