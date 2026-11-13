#!/usr/bin/env bash
# Usage: ./build.sh [check|run|build|release|loaded]
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-build}" in
	check)     odin check src -debug -vet ;;
	run)       odin run   src -debug -vet -out:jrpg ;;
	build)     odin build src -debug -vet -out:jrpg ;;
	release)   odin build src -o:speed -vet -out:jrpg-release ;;
	loaded)    odin build src -o:speed -out:jrpg-release-loaded -define:COMPILE_LOAD=true ;;
	*)         echo "unknown target: $1" >&2; exit 1 ;;
esac
