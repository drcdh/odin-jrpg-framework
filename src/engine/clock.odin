package engine

Clock :: struct {
	time:       f64, // game seconds since init; stops while paused
	dt:         f32, // game-time delta of the current frame
	raw_dt:     f32, // the clamped frame delta, unscaled and running while paused (UI animation)
	time_scale: f32,
	paused:     bool,
	frame:      u64,
}

// Long frames (window drags, breakpoints) are clamped so tweens don't jump.
MAX_DT :: f32(1.0 / 20.0)

clock_advance :: proc(raw_dt: f32) {
	c := &world.clock
	dt := min(raw_dt, MAX_DT)
	c.raw_dt = dt
	if c.paused do dt = 0
	c.dt = dt * c.time_scale
	c.time += f64(c.dt)
	c.frame += 1
}

dt   :: proc() -> f32 { return world.clock.dt }
time :: proc() -> f64 { return world.clock.time }

set_paused     :: proc(paused: bool) { world.clock.paused = paused }
set_time_scale :: proc(scale: f32)   { world.clock.time_scale = max(scale, 0) }
