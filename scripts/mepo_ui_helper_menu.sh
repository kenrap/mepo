#!/usr/bin/env sh
PROMPT="$1"

if [ ! -z "$MEPO_MENU" ]; then
  "$MEPO_MENU" "$PROMPT"
elif [ -n "$WAYLAND_DISPLAY" ]; then
  bemenu --scrollbar autohide -s -n -c -l 10 -p "$PROMPT"
elif [ -n "$DISPLAY" ]; then
  dmenu -i -l 10 -w $(xdotool getactivewindow) -p "$PROMPT"
else
  vis-menu -p "$PROMPT"
fi
