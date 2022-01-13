#!/usr/bin/env sh
DISPLAYNAME="Download: clear download queue"

main() {
  echo "cache_queueclear;"
}

if [ -n "$1" ]; then "$@"; else main; fi
