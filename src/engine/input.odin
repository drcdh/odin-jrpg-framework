package engine

import "core:fmt"
import rl "vendor:raylib"

HOLD_TIME :: 1 // second

// These are player inputs that the game understands.
// These will be (re)mapped to keyboard or controller buttons
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

GP_INPUT_MAP: map[Game_Input]rl.GamepadButton
KB_INPUT_MAP: map[Game_Input]rl.KeyboardKey

Input_Up :: struct {}
Input_Pressed :: struct {}
Input_Held :: struct {
	t: f32,
}
Single_Input_State :: union {
	Input_Up,
	Input_Pressed,
	Input_Held,
}

input_state: map[Game_Input]Single_Input_State

gamepad: i32 = 0

initialize_input :: proc() {
	GP_INPUT_MAP[Game_Input.ENTER] = rl.GamepadButton.RIGHT_FACE_DOWN
	GP_INPUT_MAP[Game_Input.CANCEL] = rl.GamepadButton.RIGHT_FACE_RIGHT
	GP_INPUT_MAP[Game_Input.MENU] = rl.GamepadButton.RIGHT_FACE_UP
	GP_INPUT_MAP[Game_Input.PAUSE] = rl.GamepadButton.MIDDLE_RIGHT
	GP_INPUT_MAP[Game_Input.UP] = rl.GamepadButton.LEFT_FACE_UP
	GP_INPUT_MAP[Game_Input.DOWN] = rl.GamepadButton.LEFT_FACE_DOWN
	GP_INPUT_MAP[Game_Input.LEFT] = rl.GamepadButton.LEFT_FACE_LEFT
	GP_INPUT_MAP[Game_Input.RIGHT] = rl.GamepadButton.LEFT_FACE_RIGHT

	KB_INPUT_MAP[Game_Input.ENTER] = rl.KeyboardKey.Z
	KB_INPUT_MAP[Game_Input.CANCEL] = rl.KeyboardKey.X
	KB_INPUT_MAP[Game_Input.MENU] = rl.KeyboardKey.S
	KB_INPUT_MAP[Game_Input.PAUSE] = rl.KeyboardKey.SPACE
	KB_INPUT_MAP[Game_Input.UP] = rl.KeyboardKey.UP
	KB_INPUT_MAP[Game_Input.DOWN] = rl.KeyboardKey.DOWN
	KB_INPUT_MAP[Game_Input.LEFT] = rl.KeyboardKey.LEFT
	KB_INPUT_MAP[Game_Input.RIGHT] = rl.KeyboardKey.RIGHT

	input_state[.ENTER] = Input_Up{}
	input_state[.CANCEL] = Input_Up{}
	input_state[.MENU] = Input_Up{}
	input_state[.PAUSE] = Input_Up{}
	input_state[.UP] = Input_Up{}
	input_state[.DOWN] = Input_Up{}
	input_state[.LEFT] = Input_Up{}
	input_state[.RIGHT] = Input_Up{}

	if rl.IsGamepadAvailable(gamepad) {
		fmt.printfln("Gamepad %d available: %s", gamepad, rl.GetGamepadName(0))
	}
}

delete_input :: proc() {
	delete(GP_INPUT_MAP)
	delete(KB_INPUT_MAP)
	delete(input_state)
}

get_updated_input_state :: proc(
	dt: f32,
	g: rl.GamepadButton,
	k: rl.KeyboardKey,
	s: Single_Input_State,
) -> Single_Input_State {
	if rl.IsGamepadButtonDown(gamepad, g) || rl.IsKeyDown(k) {
		switch s in s {
		case Input_Up:
			return Input_Pressed{}
		case Input_Pressed:
			return Input_Held{t = dt}
		case Input_Held:
			return Input_Held{t = dt + s.t}
		}
	}
	if rl.IsGamepadButtonUp(gamepad, g) || rl.IsKeyUp(k) {return Input_Up{}}
	return nil
}

update_input_state :: proc(dt: f32) {
	for k in Game_Input {
		input_state[k] = get_updated_input_state(dt, GP_INPUT_MAP[k], KB_INPUT_MAP[k], input_state[k])
	}
}

get_input :: proc(k: Game_Input, down := false, silent := false) -> (v := false) {
	switch s in input_state[k] {
	case Input_Up:
		v = false
	case Input_Pressed:
		v = true
	case Input_Held:
		v = down || s.t >= HOLD_TIME
	}
	if v && !silent {
		play_sound(.UI_Blip)
	}
	return
}

get_direction_input :: proc() -> (m := Tile_Coord{}) {
	if get_input(.UP, true, true) {
		m.y -= 1
	}
	if get_input(.DOWN, true, true) {
		m.y += 1
	}
	if get_input(.LEFT, true, true) {
		m.x -= 1
	}
	if get_input(.RIGHT, true, true) {
		m.x += 1
	}
	return
}

get_menu_input :: proc() -> (m := [2]int{}) {
	if get_input(.UP) {
		m.y -= 1
	}
	if get_input(.DOWN) {
		m.y += 1
	}
	if get_input(.LEFT) {
		m.x -= 1
	}
	if get_input(.RIGHT) {
		m.x += 1
	}
	return
}

get_x_input :: proc() -> Maybe(int) {
	v := 0
	if get_input(.LEFT) {
		v -= 1
	}
	if get_input(.RIGHT) {
		v += 1
	}
	if v != 0 {
		return v
	}
	return nil
}

get_y_input :: proc() -> Maybe(int) {
	v := 0
	if get_input(.UP) {
		v -= 1
	}
	if get_input(.DOWN) {
		v += 1
	}
	if v != 0 {
		return v
	}
	return nil
}
