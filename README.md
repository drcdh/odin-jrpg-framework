### About
A major overhaul of the system in the (private) repo [odin-jrpg](https://github.com/drcdh/odin-jrpg). Instead of scripts running from a list of union-ed structs, we now have a threading system that allows us to write scripts in native Odin.

Features from the old repo were reintroduced into the new system incrementally. Claude was used in early refactoring.

Content in this repo is just to demonstrate the features. This repo can be forked and content added to make a real game.

### Requirements
Python, pytiled-parser, Tiled, Aseprite/LibreSprite.

### Windows build from Linux
Get the Windows SDK via [xwin](https://github.com/Jake-Shadle/xwin):
- `sudo apt install cargo`
- `cargo install xwin --locked`
- `mkdir -p /path/to/windows-sdk`
- `xwin splat --output /path/to/windows-sdk/`


Build with Odin (last done successfully with Odin version `dev-2026-11:ed0ee743a`):

`odin build src/ -o:speed -define:COMPILE_LOAD=true -target:windows_amd64 -windows-sdk-root:/path/to/windows-sdk/ -linker:lld -extra-linker-flags:"/libpath:/path/to/windows-sdk/sdk/lib/um/x86_64 /libpath:/path/to/windows-sdk/crt/lib/x86_64 /libpath:/path/to/windows-sdk/sdk/lib/ucrt/x86_64/" -out:jrpg-windows-release-loaded.exe`


Run with Wine (https://gitlab.winehq.org/wine/wine/-/wikis/Download):

`wine jrpg-windows-release-loaded.exe`

