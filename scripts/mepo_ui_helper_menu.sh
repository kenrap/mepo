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
    OPTSFILE="$(mktemp)"
    echo "$(cat)" > "$OPTSFILE"
    OLDVT=1
    busybox openvt -c 11 -s -w sh -c "
      clear;
      echo Mepo terminal VT menu;
      [ -p /tmp/fbp.fifo ] && { sleep .2; echo -e \"\a\" > /tmp/fbp.fifo; }
      cat \"$OPTSFILE\" | vis-menu -p \"$PROMPT\" -l 50 > $RESULTFILE
    " > /dev/null
    cat "$RESULTFILE" | tr -d "\n"
    busybox chvt "$OLDVT" > /dev/null
    rm "$RESULTFILE" "$OPTSFILE"
    [ -p /tmp/fbp.fifo ] && { sleep .2; echo -e "\b" > /tmp/fbp.fifo; }
  fi
}

if [ -n "$1" ]; then "$@"; else main; fi
