#!/usr/bin/env sh
N_LINES=17
FONT="Inconsolata"
DOC='
  Primary menuing script which uses bemenu, dmenu, sxmo-dmenu, or vis-menu
  to display menuing respectivly. The env variable PROMPT determines prompt
  label and interface is otherwise is a passthrough to dmenu/bemenu in
  taking list items as STDIN and printing picked or typed item as STDOUT.
'

bemenuinput() {
  bemenu --fn "$FONT" --scrollbar autohide -s -n -l $N_LINES -i -p "$PROMPT"
}

main() {
  [ -z "$PROMPT" ] && PROMPT="Mepo menu"

  if [ -n "$MEPO_MENU" ]; then
    # Custom menu support
    "$MEPO_MENU" "$PROMPT"
  elif pidof plasmashell >/dev/null; then
    # Plasma Mobile support
    qdbus org.kde.KWin /VirtualKeyboard org.kde.kwin.VirtualKeyboard.active true
    bemenuinput
    qdbus org.kde.KWin /VirtualKeyboard org.kde.kwin.VirtualKeyboard.active false
  elif pidof squeekboard >/dev/null; then
    # Phosh support
    busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
    bemenuinput
    busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
  elif command -v sxmo_dmenu_with_kb.sh > /dev/null; then
    # Sxmo support
    sxmo_dmenu_with_kb.sh -p "$PROMPT"
  elif [ -n "$WAYLAND_DISPLAY" ]; then
    # Generic Wayland enviroment support
    bemenuinput
  elif [ -n "$DISPLAY" ]; then
    # Generic X enviroment support
    dmenu -fn "$FONT" -i -l $N_LINES -w "$(xdotool getactivewindow)" -p "$PROMPT"
  else
    # Framebuffer enviroment support
    RESULTFILE="$(mktemp)"
    OPTSFILE="$(mktemp)"
    cat > "$OPTSFILE"
    OLDVT=1
    busybox openvt -c 11 -s -w sh -c "
      clear;
      echo Mepo terminal VT menu;
      [ -p /tmp/fbp.fifo ] && { sleep .2; printf %b \"\a\" > /tmp/fbp.fifo; }
      cat \"$OPTSFILE\" | vis-menu -p \"$PROMPT\" -l 50 > $RESULTFILE
    " > /dev/null
    cat "$RESULTFILE" | tr -d "\n"
    busybox chvt "$OLDVT" > /dev/null
    rm "$RESULTFILE" "$OPTSFILE"
    [ -p /tmp/fbp.fifo ] && { sleep .2; printf %b "\b" > /tmp/fbp.fifo; }
  fi
}

if [ -n "$1" ]; then "$@"; else main; fi
