#!/usr/bin/env sh
DISPLAYNAME="ﰸ Download: clear download queue"
HOTKEY=w

main() {
  echo "cache_queueclear;"
}

if [ -n "$1" ]; then "$@"; else main; fi
