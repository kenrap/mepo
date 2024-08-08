#!/usr/bin/env sh
DISPLAYNAME="↺ State: Load"
HOTKEY=u
DOC='
  Loads the state (pins & preferences) from ~/.cache/mepo/savestate.json
'

main() {
  echo '
    [{
      "cmd": "fileload",
      "args": {
        "filepath": "$XDG_CACHE_HOME/mepo/savestate.json"
      }
    }]
  '
}

if [ -n "$1" ]; then "$@"; else main; fi
