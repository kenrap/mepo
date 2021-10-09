#!/usr/bin/env sh
PROMPT="$1"

MENU="dmenu -w $(xdotool getactivewindow)"

[ -n "$WAYLAND_DISPLAY" ] && MENU="bemenu --scrollbar autohide -s -n -c"

if [ -z "$MEPO_MENU" ]; then
  eval "$MENU -l 10 -p $PROMPT"
else
  "$MEPO_MENU" "$PROMPT"
fi
