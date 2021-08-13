#!/usr/bin/env sh
[ -z "$MEPO_MENU" ] && MEPO_MENU="dmenu -l 10 -w $(xdotool getactivewindow) -p"

OPTIONS='
  bind_key (key) (command)
  center_on_coords (lat) (lon)
  center_on_mouse
  move_relative (x) (y)
  pin_add (lat) (lon) (name)
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
    $MEPO_MENU "Command"
)"

echo "$CMD;"
