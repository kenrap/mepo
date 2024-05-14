#!/usr/bin/env sh
DISPLAYNAME="⚙ Update: Online/Offline toggle"
HOTKEY=m
DOC='
  Toggles the UI between offline and online mode (e.g. flipping the
  preference tile_cache_network).
'

main() {
  echo '[{
    "cmd": "preftoggle",
    "args": {
      "pref": "tile_cache_network"
    }
  }]'
}

if [ -n "$1" ]; then "$@"; else main; fi
