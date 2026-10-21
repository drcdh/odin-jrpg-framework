#!/usr/bin/env bash
# Usage: ./build_data.sh
cd "$(dirname "$0")"

python src/build_tools/process_sprites.py
python src/build_tools/process_tiled.py
