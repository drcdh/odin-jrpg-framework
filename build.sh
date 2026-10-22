#!/usr/bin/env bash
# Usage: ./build.sh [run|build|release|test]
set -euo pipefail
cd "$(dirname "$0")"

./data_build.sh

mkdir -p build

case "${1:-run}" in
	run)     odin run   src -debug -vet -out:build/odin-jrpg ;;
	build)   odin build src -debug -vet -out:build/odin-jrpg ;;
	release) odin build src -o:speed -vet -out:build/odin-jrpg ;;
	# The game keeps its state in package globals, so tests must run one at a time.
	test)
		# The rules package must stay headless: it builds alone and imports
		# neither the game, raylib nor real time.
		odin check src/rules -no-entry-point -vet
		if grep -nE '"(\.\./game|vendor:raylib|core:time)"' src/rules/*.odin; then
			echo "src/rules must not import the game, raylib or core:time" >&2
			exit 1
		fi
		odin test  src/game -debug -vet -define:ODIN_TEST_THREADS=1 -out:build/game_test ;;
	*)       echo "unknown target: $1" >&2; exit 1 ;;
esac
