package engine

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

// One box at a time. The engine doesn't read input: the game calls
// dialogue_dismiss (e.g. on Z) and should ignore movement while dialogue_active.
Dialogue :: struct {
	text:    string, // owned by the speaking script; valid while it waits in say()
	speaker: string,
	owner:   Script_Id,
}

dialogue_active :: proc() -> bool {
	return world.dialogue.owner != {}
}

dialogue_dismiss :: proc() {
	world.dialogue = {}
}

// Shows `text` in the dialogue box and blocks until it's dismissed. If another
// script's dialogue is showing, waits for it to close first. Returns false if
// the script was cancelled; a cancelled speaker's box is removed.
say :: proc(text: string, speaker := "", loc := #caller_location) -> bool {
	s := current_script
	assert(s != nil, "say called outside of a script", loc)

	if !wait_until(proc(_: rawptr) -> bool { return !dialogue_active() }, nil, loc) do return false
	world.dialogue = {text, speaker, s.handle}

	ok := wait_until(proc(data: rawptr) -> bool {
		return world.dialogue.owner != (^Script)(data).handle
	}, s, loc)
	if world.dialogue.owner == s.handle do dialogue_dismiss()
	return ok
}

// Screen space: a box along the bottom with word-wrapped text.
draw_dialogue :: proc() {
	if !dialogue_active() do return
	d := world.dialogue

	FONT    :: 28
	PADDING :: 20
	MARGIN  :: 40
	sw, sh := rl.GetScreenWidth(), rl.GetScreenHeight()
	box := rl.Rectangle{MARGIN, f32(sh) - 200, f32(sw) - 2 * MARGIN, 160}
	rl.DrawRectangleRec(box, {20, 20, 32, 235})
	rl.DrawRectangleLinesEx(box, 3, rl.RAYWHITE)

	x := i32(box.x) + PADDING
	y := i32(box.y) + PADDING
	if d.speaker != "" {
		rl.DrawText(fmt.ctprintf("%s", d.speaker), x, y, FONT, rl.GOLD)
		y += FONT + 8
	}
	for line in wrap_text(d.text, FONT, i32(box.width) - 2 * PADDING) {
		rl.DrawText(line, x, y, FONT, rl.RAYWHITE)
		y += FONT + 6
	}

	// Blinking prompt in the bottom-right corner.
	if int(rl.GetTime() * 2) % 2 == 0 {
		rl.DrawText("Z", i32(box.x + box.width) - PADDING - 16, i32(box.y + box.height) - PADDING - FONT, FONT, rl.GRAY)
	}
}

// Greedy word wrap at spaces; also breaks on '\n'. Lines are temp-allocated.
@(private)
wrap_text :: proc(text: string, font_size, max_width: i32) -> []cstring {
	lines := make([dynamic]cstring, context.temp_allocator)
	for paragraph in strings.split_lines(text, context.temp_allocator) {
		current := strings.builder_make(context.temp_allocator)
		for word in strings.fields(paragraph, context.temp_allocator) {
			candidate := word if strings.builder_len(current) == 0 else fmt.tprintf("%s %s", strings.to_string(current), word)
			if strings.builder_len(current) > 0 && rl.MeasureText(fmt.ctprintf("%s", candidate), font_size) > max_width {
				append(&lines, fmt.ctprintf("%s", strings.to_string(current)))
				strings.builder_reset(&current)
				strings.write_string(&current, word)
			} else {
				strings.builder_reset(&current)
				strings.write_string(&current, candidate)
			}
		}
		append(&lines, fmt.ctprintf("%s", strings.to_string(current)))
	}
	return lines[:]
}
