#!/usr/bin/env sh

main() {
  [ -z "$PROMPT" ] && PROMPT="Mepo menu"

  if [ ! -z "$MEPO_MENU" ]; then
    # Custom menu support
    "$MEPO_MENU" "$PROMPT"
  elif [ -n "$WAYLAND_DISPLAY" ]; then
    # Wayland enviroment support
    bemenu --scrollbar autohide -s -n -c -l 10 -p "$PROMPT"
  elif [ -n "$DISPLAY" ]; then
    # X enviroment support
    dmenu -i -l 10 -w $(xdotool getactivewindow) -p "$PROMPT"
  else
    # Framebuffer enviroment support
    RESULTFILE="$(mktemp)"
    OPTS="$(cat)"
    OLDVT=1
    openvt -c 22 -s -w sh -c "
      clear;
      echo Mepo terminal VT menu;
      echo \"$OPTS\" | vis-menu -p \"$PROMPT\" -l 50 > $RESULTFILE
    " > /dev/null
    cat "$RESULTFILE" | tr -d "\n"
    chvt "$OLDVT" >/dev/null
  fi
}

if [ -n "$1" ]; then "$@"; else main; fi
