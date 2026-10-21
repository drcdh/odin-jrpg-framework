package engine

import rl "vendor:raylib"

// Full-screen color overlay. `alpha` (0..255) is what gets tweened; the
// color's own alpha only sets where a flash starts.
Screen_Flash :: struct {
	color: rl.Color,
	alpha: f32,
}

// Covers the screen with `color` at its own alpha, fading to clear over
// `duration`. Returns immediately; a new flash replaces one in progress.
tween_flash :: proc(color: rl.Color, duration: f32, easing := Ease.Linear) -> Tween_Id {
	world.flash = {color, f32(color.a)}
	return tween_f32(&world.flash.alpha, 0, duration, easing)
}

// Fades the screen to black (`alpha` 1) or back to clear (0), for level
// changes. Returns immediately; wait on the tween to know when it's done.
curtain_to :: proc(alpha: f32, duration: f32, easing := Ease.Linear) -> Tween_Id {
	return tween_f32(&world.curtain, alpha, duration, easing)
}

// Screen space: call after EndMode2D and before the dialogue box and HUD.
draw_screen_effects :: proc() {
	w, h := rl.GetScreenWidth(), rl.GetScreenHeight()
	if world.flash.alpha > 0 {
		c := world.flash.color
		c.a = u8(clamp(world.flash.alpha, 0, 255))
		rl.DrawRectangle(0, 0, w, h, c)
	}
	if world.curtain > 0 {
		rl.DrawRectangle(0, 0, w, h, {0, 0, 0, u8(clamp(world.curtain, 0, 1) * 255)})
	}
}
