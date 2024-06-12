#!/usr/bin/env sh
DISPLAYNAME="⊗ Download: purge download queue"
HOTKEY=w
DOC='
  Clears the current download cache (background downloading of tiles).
'

main() {
  echo '[{
    "cmd": "cache_queueclear", 
    "args": {}
  }]'
}

if [ -n "$1" ]; then "$@"; else main; fi
