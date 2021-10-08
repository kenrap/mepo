#!/usr/bin/env sh
PROMPT="$1"

if [ -z "$MEPO_MENU" ]; then
  dmenu -l 10 -w "$(xdotool getactivewindow)" -p "$PROMPT"
else
  "$MEPO_MENU" "$PROMPT"
fi
