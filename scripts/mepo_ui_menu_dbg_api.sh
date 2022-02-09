#!/usr/bin/env sh
DISPLAYNAME=" Debug: API"

main() {
  OPTIONS='
    bind_key (key) (command)
    center_on_coords (lat) (lon)
    center_on_mouse
    move_relative (x) (y)
    pin_add (is_structural) (lat) (lon) (handle) (name)
    pin_cycle (index)
    pin_deactivate
    pin_purge
    prefset (pref) (value)
    shellpipe (command)
    zoom_relative (index)
  '

  CMD="$(
    echo "$OPTIONS" |
      awk '{$1=$1};1' | 
      grep . | 
      PROMPT="Command" mepo_ui_helper_menu.sh
  )"

  echo "$CMD;"
}

if [ -n "$1" ]; then "$@"; else main; fi
