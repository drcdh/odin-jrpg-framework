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
	# The engine keeps its state in package globals, so tests must run one at a time.
	test)
		# The game package must stay headless: it builds alone and imports
		# neither the engine, raylib nor real time.
		odin check src/game -no-entry-point -vet
		if grep -nE '"(\.\./engine|vendor:raylib|core:time)"' src/game/*.odin; then
			echo "src/game must not import the engine, raylib or core:time" >&2
			exit 1
		fi
		odin test  src/engine -debug -vet -define:ODIN_TEST_THREADS=1 -out:build/engine_test ;;
	*)       echo "unknown target: $1" >&2; exit 1 ;;
esac
