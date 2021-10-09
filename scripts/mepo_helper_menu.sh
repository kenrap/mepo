#!/usr/bin/env sh
PROMPT="$1"

if [ -z "$MEPO_MENU" ]; then
  if [ -n "$WAYLAND_DISPLAY" ]; then
    bemenu --scrollbar autohide -s -n -c -l 10 -p "$PROMPT"
  else
    dmenu -l 10 -w $(xdotool getactivewindow) -p "$PROMPT"
  fi
else
  "$MEPO_MENU" "$PROMPT"
fi
