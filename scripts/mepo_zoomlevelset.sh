#!/usr/bin/env sh
[ -z "$MEPO_MENU" ] && MEPO_MENU="dmenu -l 10 -w $(xdotool getactivewindow) -p"

echo prefset zoom "$(
  seq 1 16 |
  $MEPO_MENU "Zoom"
);"
