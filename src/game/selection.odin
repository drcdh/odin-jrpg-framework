package game

Selection :: struct {
	// these indices are relative to the source data structure
	origin_idx: int, // index of top element being displayed
	select_idx: int, // index of element indicated
}

// selection_row returns an index relative to the top of the displayed sublist
selection_row :: proc(s: Selection) -> int {
	return s.select_idx - s.origin_idx
}

selection_row_f :: proc(s: Selection) -> f32 {
	return f32(selection_row(s))
}

shift_windowed_selection_a :: proc(d, s, w, W, N: int) -> (int, int) {
	s, w := s, w
	s += d
	if s < 0 {
		s = N - 1
		w = max(0, N - W)
	} else if s >= N {
		s = 0
		w = 0
	} else if s >= w + W {
		w = s - W + 1
	} else if s < w {
		w = s
	}
	return s, w
}

shift_windowed_selection_b :: proc(d: int, sel: Selection, W, N: int) -> Selection {
	_s, _w := shift_windowed_selection_a(d, sel.select_idx, sel.origin_idx, W, N)
	return {origin_idx = _w, select_idx = _s}
}

shift_windowed_selection :: proc {
	shift_windowed_selection_a,
	shift_windowed_selection_b,
}
