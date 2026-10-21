package engine

/*
Script runtime: thread handoff.

Every running script gets its own OS thread, but only one thread runs at any
moment. The main thread resumes a script and blocks until that script yields
(or returns), so scripts are plain blocking Odin code that can touch game
state freely: no locks, deterministic order (spawn order, every frame).

Rules for script bodies:
- Never call raylib GPU/draw procs (LoadTexture, Draw*). The GL context belongs
  to the main thread. Math helpers and input queries are fine.
- Never hold an ^Entity across a blocking verb. Keep the Entity_Id.
- Blocking verbs return false once the script is cancelled (its entity was
  destroyed, script_cancel, shutdown). Loops must check this and return.
- Every loop must hit a blocking verb, or the game freezes.
*/

import hm "core:container/handle_map"
import "core:log"
import "base:runtime"
import "core:sync"
import "core:thread"
import "core:time"

Script_Id   :: distinct hm.Handle32
Script_Proc :: #type proc(self: Entity_Id)

Script :: struct {
	handle:           Script_Id,
	name:             string,
	procedure:        Script_Proc,
	self:             Entity_Id,
	thread:           ^thread.Thread,
	resume:           sync.Sema, // main -> script: run until your next yield
	yielded:          sync.Sema, // script -> main: I'm blocked (or finished)
	wait:             Wait,      // nil = ready to run
	done:             bool,
	cancel_requested: bool,
}

Wait :: union {
	Wait_Time,
	Wait_Frame,
	Wait_Tween,
	Wait_Script,
	Wait_Pred,
}

Wait_Time   :: struct { until: f64 }
Wait_Frame  :: struct {}
Wait_Tween  :: struct { tween: Tween_Id }
Wait_Script :: struct { script: Script_Id }
Wait_Pred   :: struct { pred: proc(data: rawptr) -> bool, data: rawptr } // evaluated on the main thread

// Debug builds warn when a script runs this long without yielding.
WATCHDOG_TIMEOUT :: 2 * time.Second

@(thread_local, private)
current_script: ^Script

// Starts `procedure(self)` as a script. It first runs during the next
// scripts_update (or later in the current one, if spawned from a script).
spawn :: proc(procedure: Script_Proc, self: Entity_Id = {}, name := "") -> Script_Id {
	h, err := hm.add(&world.scripts, Script{name = name, procedure = procedure, self = self})
	assert(err == nil, "out of memory spawning script")
	s := hm.get(&world.scripts, h)

	s.thread = thread.create(script_thread_proc)
	assert(s.thread != nil, "failed to create script thread")
	s.thread.data = s // stable: handle map items live in an xar and never move
	s.thread.init_context = context
	thread.start(s.thread)

	append(&world.script_order, h)
	return h
}

script_alive :: proc(h: Script_Id) -> bool {
	s, ok := hm.get(&world.scripts, h)
	return ok && !s.done
}

script_cancel :: proc(h: Script_Id) {
	if s, ok := hm.get(&world.scripts, h); ok do s.cancel_requested = true
}

scripts_cancel_for_entity :: proc(id: Entity_Id) {
	it := hm.iterator_make(&world.scripts)
	for s, _ in hm.iterate(&it) {
		if s.self == id do s.cancel_requested = true
	}
}

// True inside a script whose cancellation was requested.
cancelled :: proc() -> bool {
	s := current_script
	return s != nil && s.cancel_requested
}

in_script :: proc() -> bool {
	return current_script != nil
}

// Main thread: resume every script whose wait is satisfied, in spawn order,
// then reap finished ones.
scripts_update :: proc() {
	assert(current_script == nil, "scripts_update called from a script")

	// Indexed loop: scripts spawned by scripts are appended and run this frame too.
	for i := 0; i < len(world.script_order); i += 1 {
		s, ok := hm.get(&world.scripts, world.script_order[i])
		if !ok || s.done do continue
		if s.cancel_requested || wait_satisfied(s.wait) {
			s.wait = nil
			script_resume(s)
		}
	}

	n := 0
	for h in world.script_order {
		s, ok := hm.get(&world.scripts, h)
		if !ok do continue
		if s.done {
			// A finished trigger script frees its entity, whoever made it busy.
			if e, has := entity_get(s.self); has && e.trigger.running == h {
				e.busy = false
				e.busy_by = {}
			}
			thread.destroy(s.thread) // joins
			hm.remove(&world.scripts, h)
		} else {
			world.script_order[n] = h
			n += 1
		}
	}
	resize(&world.script_order, n)
}

// Cancels everything and pumps until the scripts return. Scripts that ignore
// cancellation are reported and left blocked; the process exit takes them.
scripts_shutdown :: proc() {
	for h in world.script_order do script_cancel(h)
	for _ in 0..<1000 {
		if len(world.script_order) == 0 do return
		scripts_update()
	}
	for h in world.script_order {
		s := hm.get(&world.scripts, h)
		log.errorf("script %q ignored cancellation; abandoning its thread", s.name)
	}
}

@(private)
wait_satisfied :: proc(w: Wait) -> bool {
	switch v in w {
	case Wait_Time:   return world.clock.time >= v.until
	case Wait_Frame:  return true
	case Wait_Tween:  return tween_done(v.tween)
	case Wait_Script: return !script_alive(v.script)
	case Wait_Pred:   return v.pred(v.data)
	}
	return true // nil
}

@(private)
script_resume :: proc(s: ^Script) {
	sync.sema_post(&s.resume)
	when ODIN_DEBUG {
		for !sync.sema_wait_with_timeout(&s.yielded, WATCHDOG_TIMEOUT) {
			log.warnf("script %q has run for %v without yielding (missing a wait in a loop?)", s.name, WATCHDOG_TIMEOUT)
		}
	} else {
		sync.sema_wait(&s.yielded)
	}
}

// Script side: block until `w` is satisfied. Returns false if cancelled.
// A wait that is already satisfied returns at once without yielding, except
// Wait_Frame, and except after cancellation: then it always yields, so a loop
// that ignores the result still can't freeze the main thread.
@(private)
yield_until :: proc(w: Wait, loc := #caller_location) -> bool {
	s := current_script
	assert(s != nil, "blocking script verb called outside of a script", loc)
	_, is_frame := w.(Wait_Frame)
	if !s.cancel_requested && !is_frame && wait_satisfied(w) do return true

	s.wait = w
	sync.sema_post(&s.yielded)
	sync.sema_wait(&s.resume)
	return !s.cancel_requested
}

@(private)
script_thread_proc :: proc(t: ^thread.Thread) {
	s := (^Script)(t.data)
	sync.sema_wait(&s.resume)

	current_script = s
	if !s.cancel_requested do s.procedure(s.self)
	current_script = nil

	// core:thread skips this when init_context is set. It must happen before
	// handing control back, since the main thread may be using the same backing allocator.
	if context.temp_allocator.procedure == runtime.default_temp_allocator_proc {
		runtime.default_temp_allocator_destroy(auto_cast context.temp_allocator.data)
	}

	s.done = true
	sync.sema_post(&s.yielded)
}
