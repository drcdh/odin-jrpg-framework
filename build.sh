#!/usr/bin/env bash
# Usage: ./build.sh [check|run|build|release|test]
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-build}" in
	check)   odin check src -debug -vet ;;
	run)     odin run   src -debug -vet -out:jrpg ;;
	build)   odin build src -debug -vet -out:jrpg ;;
	release) odin build src -o:speed -vet -out:jrpg-release ;;
	test)    odin test  src/game -debug -vet -define:ODIN_TEST_THREADS=1 -out:test-jrpg ;;
	*)       echo "unknown target: $1" >&2; exit 1 ;;
esac
