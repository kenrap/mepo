#!/usr/bin/env sh
DISPLAYNAME="⊕ Pins: Drop pin at crosshair"
HOTKEY=f
DOC='
  Drops a pin at the crosshair location.
'

main() {
  echo '[{
    "cmd": "pin_add",
    "args": {
      "lat": '$MEPO_CENTER_LAT',
      "lon": '$MEPO_CENTER_LON',
      "handle": "'$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c10)'"
    }
  }]'
}

if [ -n "$1" ]; then "$@"; else main; fi
