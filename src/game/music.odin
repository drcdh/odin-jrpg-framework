package game

import "core:fmt"
import "core:log"
import "core:sync"
import "core:thread"
import "core:time"
import rl "vendor:raylib"

// Music streams on its own thread so it doesn't stutter on long frames or
// window drags (the pattern is from Cat & Onion by Karl Zylinski). The game
// and its scripts only store requests (play_music, music_fade_down, ...) into
// atomics; the thread owns the stream and does every raylib music call.
// Without an audio device (headless tests) no thread runs and requests are
// only recorded.

MUSIC_DIR :: "assets/audio/music" // Music_Name and music_files are generated from it (process_audio.py)

DEFAULT_MUSIC_VOLUME :: 7

MUSIC_TICK :: 10 * time.Millisecond
FADE_STEP  :: f32(0.01) // per tick: a full fade takes a second

Music_State :: struct {
	// Requests, written by the game and read by the thread.
	requested: Music_Name,
	volume:    int,  // 0..SOUND_MAX_VOLUME
	faded:     bool, // fading towards (or at) silence
	running:   bool,
	// Game side only.
	prev:      Music_Name, // the track before `requested`, for play_prev_music
	thread:    ^thread.Thread,
	// Thread side only.
	cur_name:  Music_Name,
	cur:       rl.Music,
	level:     f32, // fade level, 0..1
	applied:   f32, // the stream volume last set
}

// Switches to `m` (.None for silence). Asking for the track already playing
// changes nothing, so levels can request their music every time they start.
play_music :: proc(m: Music_Name) {
	s := &game.audio.music
	cur := sync.atomic_load(&s.requested)
	if m == cur do return
	s.prev = cur
	sync.atomic_store(&s.requested, m)
}

// Goes back to the track that played before the current one.
play_prev_music :: proc() {
	play_music(game.audio.music.prev)
}

// Fades the music out over a second; it stays silent, even across track
// changes, until music_fade_up.
music_fade_down :: proc() {
	sync.atomic_store(&game.audio.music.faded, true)
}

music_fade_up :: proc() {
	sync.atomic_store(&game.audio.music.faded, false)
}

set_music_volume :: proc(v: int) {
	sync.atomic_store(&game.audio.music.volume, clamp(v, 0, SOUND_MAX_VOLUME))
}

@(private)
music_init :: proc() {
	s := &game.audio.music
	s.volume = DEFAULT_MUSIC_VOLUME
	s.level = 1
	s.applied = -1
	if !rl.IsAudioDeviceReady() do return
	s.running = true
	if s.thread = thread.create(music_thread); s.thread != nil {
		s.thread.init_context = context
		s.thread.data = rawptr(s)
		thread.start(s.thread)
	}
}

@(private)
music_shutdown :: proc() {
	s := &game.audio.music
	if s.thread == nil do return
	sync.atomic_store(&s.running, false)
	thread.join(s.thread)
	thread.destroy(s.thread)
	s.thread = nil
}

@(private = "file")
music_thread :: proc(t: ^thread.Thread) {
	s := (^Music_State)(t.data)
	for sync.atomic_load(&s.running) {
		if sync.atomic_load(&s.faded) {
			s.level = max(s.level - FADE_STEP, 0)
		} else {
			s.level = min(s.level + FADE_STEP, 1)
		}

		if want := sync.atomic_load(&s.requested); want != s.cur_name {
			unload_music(s)
			if want != .None do s.cur = load_music(want)
			s.cur_name = want
		}

		if s.cur_name != .None {
			v := f32(sync.atomic_load(&s.volume)) / SOUND_MAX_VOLUME * s.level
			if v != s.applied {
				rl.SetMusicVolume(s.cur, v)
				s.applied = v
			}
			rl.UpdateMusicStream(s.cur)
		}
		time.sleep(MUSIC_TICK)
	}
	unload_music(s)
	s.cur_name = .None
}

// Loads and starts `m`, looping. Called on the music thread only.
@(private = "file")
load_music :: proc(m: Music_Name) -> rl.Music {
	// No temp allocator: it belongs to the main thread.
	buf: [512]u8
	path := fmt.bprintf(buf[:len(buf) - 1], "%s/%s", MUSIC_DIR, music_files[m])
	mus := rl.LoadMusicStream(cstring(&buf[0]))
	if mus.frameCount == 0 {
		log.warnf("Couldn't load music %v from %s", m, path)
		return mus
	}
	mus.looping = true
	rl.PlayMusicStream(mus)
	return mus
}

@(private = "file")
unload_music :: proc(s: ^Music_State) {
	if s.cur_name == .None do return
	rl.StopMusicStream(s.cur)
	rl.UnloadMusicStream(s.cur)
	s.cur = {}
	s.applied = -1 // set the volume on the next stream
}
