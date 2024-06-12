#!/usr/bin/env sh
DISPLAYNAME="↻ State: Save"
DOC='
  Saves the state (pins & preferences) to ~/.cache/mepo/savestate.json
'

main() {
  echo '
    [{
      "cmd": "filedump",
      "args": {
        "datatypes": "rp",
        "filepath": "$XDG_CACHE_HOME/mepo/savestate.json"
      }
    }]
  '
}

if [ -n "$1" ]; then "$@"; else main; fi
