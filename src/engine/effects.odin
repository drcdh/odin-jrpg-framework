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

// Screen space: call after EndMode2D and before the HUD.
draw_screen_effects :: proc() {
	if world.flash.alpha <= 0 do return
	c := world.flash.color
	c.a = u8(clamp(world.flash.alpha, 0, 255))
	rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), c)
}
