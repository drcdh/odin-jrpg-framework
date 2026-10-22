package engine

import "core:log"
import rl "vendor:raylib"

// Seconds a button must be held before get_input starts repeating it.
HOLD_TIME :: 1

// The player inputs the game understands. Each maps to one keyboard key and
// one gamepad button.
Game_Input :: enum {
	ENTER,
	CANCEL,
	MENU,
	PAUSE,
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

@(rodata)
KB_INPUT_MAP := [Game_Input]rl.KeyboardKey {
	.ENTER  = .Z,
	.CANCEL = .X,
	.MENU   = .S,
	.PAUSE  = .SPACE,
	.UP     = .UP,
	.DOWN   = .DOWN,
	.LEFT   = .LEFT,
	.RIGHT  = .RIGHT,
}

@(rodata)
GP_INPUT_MAP := [Game_Input]rl.GamepadButton {
	.ENTER  = .RIGHT_FACE_DOWN,
	.CANCEL = .RIGHT_FACE_RIGHT,
	.MENU   = .RIGHT_FACE_UP,
	.PAUSE  = .MIDDLE_RIGHT,
	.UP     = .LEFT_FACE_UP,
	.DOWN   = .LEFT_FACE_DOWN,
	.LEFT   = .LEFT_FACE_LEFT,
	.RIGHT  = .LEFT_FACE_RIGHT,
}

Input_Up      :: struct {}
Input_Pressed :: struct {} // down this frame, up the last
Input_Held    :: struct {
	t: f32, // seconds held since the press
}

Single_Input_State :: union #no_nil {
	Input_Up,
	Input_Pressed,
	Input_Held,
}

Input :: struct {
	state:   [Game_Input]Single_Input_State,
	gamepad: i32,
}

@(private)
input_init :: proc() {
	if rl.IsWindowReady() && rl.IsGamepadAvailable(world.input.gamepad) {
		log.infof("gamepad %d available: %s", world.input.gamepad, rl.GetGamepadName(world.input.gamepad))
	}
}

// Reads the keyboard and gamepad. Call once per frame, before the game's
// update, with the real frame time (holds keep counting while the game is paused).
input_update :: proc(dt: f32) {
	gp := world.input.gamepad
	pad := rl.IsGamepadAvailable(gp)
	for k in Game_Input {
		down := rl.IsKeyDown(KB_INPUT_MAP[k]) || (pad && rl.IsGamepadButtonDown(gp, GP_INPUT_MAP[k]))
		world.input.state[k] = next_input_state(world.input.state[k], down, dt)
	}
}

next_input_state :: proc(s: Single_Input_State, down: bool, dt: f32) -> Single_Input_State {
	if !down do return Input_Up{}
	switch v in s {
	case Input_Up:      return Input_Pressed{}
	case Input_Pressed: return Input_Held{t = dt}
	case Input_Held:    return Input_Held{t = v.t + dt}
	}
	return Input_Up{}
}

// True on the frame `k` is pressed and, once it has been held for HOLD_TIME,
// on every frame after that. With `down`, true on every frame it's held.
get_input :: proc(k: Game_Input, down := false, silent := false) -> (v: bool) {
	switch s in world.input.state[k] {
	case Input_Up:      v = false
	case Input_Pressed: v = true
	case Input_Held:    v = down || s.t >= HOLD_TIME
	}
	// TODO: play .UI_Blip when v && !silent, once audio is ported.
	return
}

// Swallows the current press of `k`, so it doesn't also count for whatever
// reads input next (the press that opens a dialogue box mustn't skip its text).
// The button counts again once released and pressed, or after HOLD_TIME.
consume_input :: proc(k: Game_Input) {
	if _, up := world.input.state[k].(Input_Up); !up do world.input.state[k] = Input_Held{}
}

// Held directions, as a tile offset; both axes can be set at once.
get_direction_input :: proc() -> (m: Tile) {
	if get_input(.UP, true, true)    do m.y -= 1
	if get_input(.DOWN, true, true)  do m.y += 1
	if get_input(.LEFT, true, true)  do m.x -= 1
	if get_input(.RIGHT, true, true) do m.x += 1
	return
}

// Pressed (or repeating) directions, for moving through menus.
get_menu_input :: proc() -> (m: [2]int) {
	if get_input(.UP)    do m.y -= 1
	if get_input(.DOWN)  do m.y += 1
	if get_input(.LEFT)  do m.x -= 1
	if get_input(.RIGHT) do m.x += 1
	return
}

get_x_input :: proc() -> Maybe(int) {
	if m := get_menu_input(); m.x != 0 do return m.x
	return nil
}

get_y_input :: proc() -> Maybe(int) {
	if m := get_menu_input(); m.y != 0 do return m.y
	return nil
}

grid_change :: proc(i, dx, dy, W, H: int) -> int {
	// if dx or dy are non-zero, their magnitude is assumed to be 1
	_i := i
	if dx < 0 {
		if i % W == 0 {
			// left edge
			_i += W - 1
		} else {
			_i -= 1
		}
	} else if dx > 0 {
		if (i + 1) % W == 0 {
			// right edge
			_i -= W - 1
		} else {
			_i += 1
		}
	}
	if dy < 0 {
		if i < W {
			// top edge
			_i += W * (H - 1)
		} else {
			_i -= W
		}
	} else if dy > 0 {
		if i >= W * (H - 1) {
			// bottom edge
			_i -= W * (H - 1)
		} else {
			_i += W
		}
	}
	return _i
}
