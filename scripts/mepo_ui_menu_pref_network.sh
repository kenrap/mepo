#!/usr/bin/env sh
DISPLAYNAME="Update: Online/Offline toggle"

main() {
  echo "preftoggle tile_cache_network;"
}

if [ -n "$1" ]; then "$@"; else main; fi

