package game

// Stand-ins for old-project code that the generated level files
// (process_tiled.py) call. They return defaults. Replace each as the real
// feature lands.

try_spawn_from_save :: proc() -> (tile: Tile, face: Direction, ok: bool) { return }
