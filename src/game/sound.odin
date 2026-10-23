package game

import "core:fmt"
import "core:log"
import "core:strings"
import rl "vendor:raylib"

// Sound effects. play_sound only queues; sounds_update plays what's due on the
// main thread, so scripts can call it from their own threads. Each sound loads
// on first play. Without an audio device (headless tests) due sounds are dropped.

SOUND_DIR :: "assets/audio/sounds" // Sound_Name and sound_files are generated from it (process_audio.py)

SOUND_MAX_VOLUME       :: 10
DEFAULT_EFFECTS_VOLUME :: 10

Pending_Sound :: struct {
	sound: Sound_Name,
	delay: f32, // game seconds left before it plays
}

Audio :: struct {
	sounds:         [Sound_Name]rl.Sound, // zero = not loaded
	pending:        [dynamic]Pending_Sound,
	effects_volume: int, // 0..SOUND_MAX_VOLUME
	music:          Music_State,
}

// Plays `n` after `delay` seconds of game time (so a paused world holds it).
play_sound :: proc(n: Sound_Name, delay: f32 = 0) {
	append(&world.audio.pending, Pending_Sound{n, delay})
}

@(private)
sounds_init :: proc(allocator := context.allocator) {
	world.audio.pending = make([dynamic]Pending_Sound, allocator)
	world.audio.effects_volume = DEFAULT_EFFECTS_VOLUME
}

@(private)
sounds_destroy :: proc() {
	for s in world.audio.sounds do if s.frameCount != 0 do rl.UnloadSound(s)
	delete(world.audio.pending)
	world.audio.sounds = {}
	world.audio.pending = nil
}

@(private)
sounds_update :: proc(dt: f32) {
	a := &world.audio
	for i := 0; i < len(a.pending); {
		p := &a.pending[i]
		p.delay -= dt
		if p.delay > 0 {
			i += 1
			continue
		}
		if rl.IsAudioDeviceReady() {
			snd := get_sound(p.sound)
			rl.SetSoundVolume(snd, f32(a.effects_volume) / SOUND_MAX_VOLUME)
			rl.PlaySound(snd)
		}
		ordered_remove(&a.pending, i) // same-frame sounds start in call order
	}
}

@(private = "file")
get_sound :: proc(n: Sound_Name) -> rl.Sound {
	s := &world.audio.sounds[n]
	if s.frameCount == 0 {
		path := fmt.tprintf("%s/%s", SOUND_DIR, sound_files[n])
		s^ = rl.LoadSound(strings.clone_to_cstring(path, context.temp_allocator))
		if s.frameCount == 0 do log.warnf("Couldn't load sound %v from %s", n, path)
	}
	return s^
}
