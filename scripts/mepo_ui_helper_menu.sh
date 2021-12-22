#!/usr/bin/env sh

main() {
  [ -z "$PROMPT" ] && PROMPT="Mepo menu"

  if [ ! -z "$MEPO_MENU" ]; then
    "$MEPO_MENU" "$PROMPT"
  elif [ -n "$WAYLAND_DISPLAY" ]; then
    bemenu --scrollbar autohide -s -n -c -l 10 -p "$PROMPT"
  elif [ -n "$DISPLAY" ]; then
    dmenu -i -l 10 -w $(xdotool getactivewindow) -p "$PROMPT"
  else
    vis-menu -p "$PROMPT"
  fi
}

if [ -n "$1" ]; then "$@"; else main; fi
