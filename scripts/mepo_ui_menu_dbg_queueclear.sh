#!/usr/bin/env sh
DISPLAYNAME="⊗ Download: clear download queue"
HOTKEY=w
DOC='
  Clears the current download cache (background downloading of tiles).
'

main() {
  echo "cache_queueclear;"
}

if [ -n "$1" ]; then "$@"; else main; fi
