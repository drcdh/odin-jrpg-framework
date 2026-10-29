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
	test)
		odin test  src/game -debug -vet -define:ODIN_TEST_THREADS=1 -out:build/odin-jrpg-test ;;
	*)       echo "unknown target: $1" >&2; exit 1 ;;
esac
