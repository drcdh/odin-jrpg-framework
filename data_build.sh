#!/usr/bin/env bash
# Usage: ./build_data.sh
cd "$(dirname "$0")"

python src/build_tools/generate_font.py
python src/build_tools/process_audio.py
python src/build_tools/process_baddies.py
python src/build_tools/process_bb.py
python src/build_tools/process_encounters.py
python src/build_tools/process_items.py
python src/build_tools/process_skills.py
python src/build_tools/process_sprites.py
python src/build_tools/process_tiled.py
