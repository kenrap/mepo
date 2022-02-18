#!/usr/bin/env sh
DISPLAYNAME="痢 Update: Online/Offline toggle"
HOTKEY=m

main() {
  echo "preftoggle tile_cache_network;"
}

if [ -n "$1" ]; then "$@"; else main; fi
