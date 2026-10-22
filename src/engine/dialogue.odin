package engine

import "core:strings"
import rl "vendor:raylib"

// The dialogue box: a pane across the top of the screen that types out text
// a character at a time, a page of `lines` lines at a time, with an optional
// speaker line and a pane of choices below. Scripts drive it with say and
// choose; it reads ENTER and UP/DOWN itself (input.odin).

DIALOGUE_SPEED         :: f32(0.05) // seconds per character
DEFAULT_DIALOGUE_LINES :: 4
MAX_DIALOGUE_LINES     :: 24
DIALOGUE_ORIGIN        :: [2]f32{0, 0} // UI tiles

Dialogue_Hidden  :: struct {}
Dialogue_Marquee :: struct { t: f32 } // typing; t is the time to the next character
Dialogue_Pause   :: struct { t: f32 } // the page is out; waiting `pause` seconds
Dialogue_Wait    :: struct {}         // the page is out; waiting for ENTER
Dialogue_Choose  :: struct {}         // the text is out; picking a choice
Dialogue_Done    :: struct {}         // finished; the speaking script resumes

Dialogue_State :: union #no_nil {
	Dialogue_Hidden,
	Dialogue_Marquee,
	Dialogue_Pause,
	Dialogue_Wait,
	Dialogue_Choose,
	Dialogue_Done,
}

// A line of the current page: a byte range of `buffer`.
@(private)
Dialogue_Line :: struct { start, end: int }

Dialogue :: struct {
	state:      Dialogue_State,
	owner:      Script_Id,
	lines:      int, // per page, including the speaker line
	line_width: int, // characters

	buffer:     strings.Builder, // the text since the box was last cleared
	page_start: int,             // where the current page starts
	buffer_end: int,             // where the next page starts
	page:       [MAX_DIALOGUE_LINES]Dialogue_Line,
	page_len:   int,
	shown:      int, // characters of the page typed out so far

	speaker:    strings.Builder,
	choices:    [dynamic]string, // cloned
	choice:     int,             // the highlighted choice; the result once Done
	hurry:      bool,            // finish without waiting for ENTER
	pause:      f32,             // seconds to hold the finished text first
}

@(private)
dialogue_init :: proc(allocator := context.allocator) {
	d := &world.dialogue
	d.state = Dialogue_Hidden{}
	d.lines = DEFAULT_DIALOGUE_LINES
	// The old game's width: the screen less a tile of border.
	d.line_width = 2 * VIEW_TILES_W - 2
	strings.builder_init(&d.buffer, allocator)
	strings.builder_init(&d.speaker, allocator)
	d.choices = make([dynamic]string, allocator)
}

@(private)
dialogue_destroy :: proc() {
	d := &world.dialogue
	dialogue_clear_choices()
	delete(d.choices)
	strings.builder_destroy(&d.speaker)
	strings.builder_destroy(&d.buffer)
}

dialogue_active :: proc() -> bool {
	_, hidden := world.dialogue.state.(Dialogue_Hidden)
	return !hidden
}

// Types `text` into the dialogue box and blocks until it's been read: the
// player presses ENTER on the last page, or with `hurry`, right away once it's
// typed. `pause` holds the finished text that many seconds first. With `clear`
// false, the text carries on from what's in the box, on the same page. A non-empty `speaker`
// takes the first line in gold. Words wrap at spaces; "\n" breaks a line.
//
// If another script's dialogue is up, waits for it to close first. Returns
// false if the script was cancelled; a cancelled speaker's box closes. The box
// closes once the speaking script stops talking (doesn't say or choose again
// on the frame it resumes), so a run of says reads as one conversation.
say :: proc(text: string, speaker := "", hurry := false, pause: f32 = 0, clear := true, loc := #caller_location) -> bool {
	return dialogue_show(text, speaker, nil, hurry, pause, clear, loc)
}

// Like say, then offers `choices` in a pane below the text. UP and DOWN move
// the highlight (wrapping around), ENTER picks. Returns the chosen index.
choose :: proc(text: string, choices: []string, speaker := "", loc := #caller_location) -> (choice: int, ok: bool) {
	assert(len(choices) > 0, "choose needs at least one choice", loc)
	ok = dialogue_show(text, speaker, choices, false, 0, true, loc)
	return world.dialogue.choice, ok
}

@(private)
dialogue_show :: proc(text, speaker: string, choices: []string, hurry: bool, pause: f32, clear: bool, loc := #caller_location) -> bool {
	s := current_script
	assert(s != nil, "say/choose called outside of a script", loc)

	// Wait for the box unless it's free or this script is mid-conversation.
	free := wait_until(proc(data: rawptr) -> bool {
		return !dialogue_active() || world.dialogue.owner == (^Script)(data).handle
	}, s, loc)
	if !free do return false

	d := &world.dialogue
	carry_on := !clear && dialogue_active()
	if !carry_on {
		strings.builder_reset(&d.buffer)
		d.buffer_end = 0
	}
	strings.write_string(&d.buffer, text)
	strings.builder_reset(&d.speaker)
	strings.write_string(&d.speaker, speaker)
	dialogue_clear_choices()
	for c in choices do append(&d.choices, strings.clone(c, d.buffer.buf.allocator))
	d.choice = 0
	d.hurry = hurry
	d.pause = pause
	d.owner = s.handle
	if carry_on {
		// Carry on typing the page on screen, re-wrapped with the new text.
		d.buffer_end = d.page_start
		dialogue_next_page(keep_shown = true)
	} else {
		dialogue_next_page()
	}
	// The press that started this (talking to someone) mustn't skip the text.
	consume_input(.ENTER)

	ok := wait_until(proc(data: rawptr) -> bool {
		_, done := world.dialogue.state.(Dialogue_Done)
		return done || world.dialogue.owner != (^Script)(data).handle
	}, s, loc)
	if !ok && d.owner == s.handle do dialogue_close()
	return ok
}

// Runs the box: typing, paging, choices. Call after scripts_update, so a
// script that finishes one say and starts the next in the same frame keeps
// the box open.
@(private)
dialogue_update :: proc(dt: f32) {
	d := &world.dialogue
	switch &s in d.state {
	case Dialogue_Hidden:
	case Dialogue_Marquee:
		total := dialogue_page_chars()
		if get_input(.ENTER) {
			d.shown = total // skip the typing
		} else {
			s.t -= dt
			for s.t <= 0 && d.shown < total {
				d.shown += 1
				s.t += DIALOGUE_SPEED
			}
		}
		if d.shown >= total do dialogue_page_typed()
	case Dialogue_Pause:
		s.t -= dt
		if s.t <= 0 do dialogue_page_out()
	case Dialogue_Wait:
		if get_input(.ENTER) {
			if dialogue_more_pages() {
				dialogue_next_page()
			} else {
				d.state = Dialogue_Done{}
			}
		}
	case Dialogue_Choose:
		if get_input(.ENTER) {
			d.state = Dialogue_Done{}
		} else if dy, ok := get_y_input().?; ok {
			d.choice = (d.choice + dy) %% len(d.choices)
		}
	case Dialogue_Done:
		// The speaker resumed this frame and didn't carry on talking.
		dialogue_close()
	}
}

// Screen space: the dialogue pane, then the choice pane under it.
draw_dialogue :: proc() {
	d := &world.dialogue
	if !dialogue_active() || world.ui.font.texture.id == 0 do return
	o := DIALOGUE_ORIGIN
	w := view_tiles().x
	draw_pane(o.x, o.y, w, f32(d.lines + 2) / 2)

	row := 0
	if strings.builder_len(d.speaker) > 0 {
		draw_text(o.x + .5, o.y + .5, strings.clone_to_cstring(strings.to_string(d.speaker), context.temp_allocator), rl.GOLD)
		row = 1
	}
	text := strings.to_string(d.buffer)
	remaining := d.shown
	for l in d.page[:d.page_len] {
		n := min(l.end - l.start, remaining)
		remaining -= n
		line := strings.clone_to_cstring(text[l.start:][:n], context.temp_allocator)
		draw_text(o.x + .5, o.y + f32(row + 1) / 2, line)
		row += 1
	}

	#partial switch _ in d.state {
	case Dialogue_Wait:
		draw_sprite(world.ui.dialogue_icon, ui_to_screen(o.x + w - 1, o.y + f32(d.lines / 2)))
	case Dialogue_Choose:
		draw_pane(o.x, o.y + f32(d.lines + 2) / 2, w, f32(len(d.choices) + 2) / 2)
		for c, i in d.choices {
			color := rl.YELLOW if i == d.choice else rl.GRAY
			draw_text(o.x + .5, o.y + f32(i + d.lines + 2) / 2 + .5, strings.clone_to_cstring(c, context.temp_allocator), color)
		}
	}
}

// Splits `text` from `start` into at most `lines` lines of at most `width`
// characters, breaking after the last space that fits (or hard, mid-word, if
// there's none) and at "\n". Returns the lines and where the next page starts.
@(private)
wrap_page :: proc(text: string, start, lines, width: int, out: []Dialogue_Line) -> (n: int, next: int) {
	next = start
	for n < lines && next < len(text) {
		rest := text[next:]
		line_end: int  // relative to next
		skip := 0      // the space or newline the line breaks on
		if nl := strings.index_byte(rest[:min(len(rest), width + 1)], '\n'); nl >= 0 && nl <= width {
			line_end, skip = nl, 1
		} else if len(rest) <= width {
			line_end = len(rest)
		} else if rest[width] == ' ' {
			line_end, skip = width, 1
		} else if sp := strings.last_index_byte(rest[:width], ' '); sp > 0 {
			line_end, skip = sp, 1
		} else {
			line_end = width
		}
		out[n] = {next, next + line_end}
		n += 1
		next += line_end + skip
	}
	return
}

@(private = "file")
dialogue_text_lines :: proc() -> int {
	d := &world.dialogue
	return d.lines - 1 if strings.builder_len(d.speaker) > 0 else d.lines
}

@(private = "file")
dialogue_next_page :: proc(keep_shown := false) {
	d := &world.dialogue
	d.page_start = d.buffer_end
	d.page_len, d.buffer_end = wrap_page(strings.to_string(d.buffer), d.buffer_end, dialogue_text_lines(), d.line_width, d.page[:])
	if !keep_shown do d.shown = 0
	d.shown = min(d.shown, dialogue_page_chars())
	d.state = Dialogue_Marquee{t = DIALOGUE_SPEED}
}

@(private = "file")
dialogue_more_pages :: proc() -> bool {
	d := &world.dialogue
	return d.buffer_end < strings.builder_len(d.buffer)
}

@(private = "file")
dialogue_page_chars :: proc() -> (total: int) {
	d := &world.dialogue
	for l in d.page[:d.page_len] do total += l.end - l.start
	return
}

// The page is fully typed: hold it for `pause`, or move on.
@(private = "file")
dialogue_page_typed :: proc() {
	d := &world.dialogue
	if d.pause > 0 && !dialogue_more_pages() {
		d.state = Dialogue_Pause{t = d.pause}
		d.pause = 0
		return
	}
	dialogue_page_out()
}

// What follows a finished page: more pages and the last page wait for ENTER,
// unless there are choices to make or the text is in a hurry.
@(private = "file")
dialogue_page_out :: proc() {
	d := &world.dialogue
	switch {
	case dialogue_more_pages(): d.state = Dialogue_Wait{}
	case len(d.choices) > 0:    d.state = Dialogue_Choose{}
	case d.hurry:               d.state = Dialogue_Done{}
	case:                       d.state = Dialogue_Wait{}
	}
}

@(private = "file")
dialogue_close :: proc() {
	d := &world.dialogue
	strings.builder_reset(&d.buffer)
	strings.builder_reset(&d.speaker)
	dialogue_clear_choices()
	d.page_start = 0
	d.buffer_end = 0
	d.page_len = 0
	d.shown = 0
	d.owner = {}
	d.state = Dialogue_Hidden{}
}

@(private = "file")
dialogue_clear_choices :: proc() {
	d := &world.dialogue
	for c in d.choices do delete(c, d.buffer.buf.allocator)
	clear(&d.choices)
}
