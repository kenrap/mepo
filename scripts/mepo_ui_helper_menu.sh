#!/usr/bin/env sh
N_LINES=15
FONT="Inconsolata"

main() {
  [ -z "$PROMPT" ] && PROMPT="Mepo menu"

  if [ ! -z "$MEPO_MENU" ]; then
    # Custom menu support
    "$MEPO_MENU" "$PROMPT"
  elif pidof squeekboard >/dev/null; then
    # Phosh support
    busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
    bemenu --fn "$FONT" --scrollbar autohide -s -n -c -l $N_LINES -i -p "$PROMPT"
    busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
  elif command -v sxmo_dmenu_with_kb.sh; then
    # Sxmo support
    sxmo_dmenu_with_kb.sh
  elif [ -n "$WAYLAND_DISPLAY" ]; then
    # Generic Wayland enviroment support
    bemenu --fn "$FONT" --scrollbar autohide -s -n -c -l $N_LINES -i -p "$PROMPT"
  elif [ -n "$DISPLAY" ]; then
    # Generic X enviroment support
    dmenu -fn "$FONT" -i -l $N_LINES -w $(xdotool getactivewindow) -p "$PROMPT"
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
