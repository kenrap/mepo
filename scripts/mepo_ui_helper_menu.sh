#!/usr/bin/env sh
DOC='
  Primary menuing script which uses bemenu, dmenu, sxmo-dmenu, or vis-menu
  to display menuing respectivly. The env variable PROMPT determines prompt
  label and interface is otherwise is a passthrough to dmenu/bemenu in
  taking list items as STDIN and printing picked or typed item as STDOUT.
'
[ -z "$MEPO_MENUING" ] && MEPO_MENUING=auto
[ -z "$MEPO_MENUING_FONT" ] && MEPO_MENUING_FONT=Inconsolata
[ -z "$MEPO_MENUING_NLINES" ] && MEPO_MENUING_NLINES=17

zenitydims() {
  DIMS="$(
    xwininfo -tree -root |
      grep '("mepo" "mepo")' |
      awk '{$1=$1};1' |
      cut -d' ' -f1 |
      xargs xwininfo -id |
      grep -- -geometry |
      grep -oE '[0-9]+x[0-9]+'
  )"
  DIMW="$(echo $DIMS | cut -dx -f1 | xargs echo "0.8 *" | bc | cut -d. -f1)"
  DIMH="$(echo $DIMS | cut -dx -f2 | xargs echo "0.8 *" | bc | cut -d. -f1)"

  if echo "$DIMW" | grep -Eq '[0-9]+' && echo "$DIMH" | grep -Eq '[0-9]+'; then
    echo "--width $DIMW --height $DIMH"
  fi
}

inputzenity() {
  if [ "$TEXTINPUT" = 1 ]; then
    zenity $(zenitydims) --title "Type input" --entry --text "$PROMPT"
  else
    OPTS="$(cat)\nType Custom"
    OPTS="$(printf %b "$OPTS" | tr -d \" | awk NF)"
    RESULT="$(
      echo "$OPTS" |
      xargs -d$'\n' zenity $(zenitydims) --title "Select an entry" --list --column=Selection --text "$PROMPT"
    )"
    if [ "$RESULT" = "Type Custom" ]; then
      TEXTINPUT=1 inputzenity
    else
      echo "$RESULT"
    fi
  fi
}

inputbemenu() {
  bemenu --fn "$MEPO_MENUING_FONT" --scrollbar autohide -s -n -l $MEPO_MENUING_NLINES -i -p "$PROMPT"
}

inputframebuffer() {
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
}

inputbemenuphosh() {
  busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
  inputbemenu
  busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
}

inputdmenu() {
  dmenu -fn "$MEPO_MENUING_FONT" -i -l $MEPO_MENUING_NLINES -w "$(xdotool getactivewindow)" -p "$PROMPT"
}

inputsxmodmenu() {
  sxmo_dmenu_with_kb.sh -p "$PROMPT"
}

hascommand() {
  command -v "$1" > /dev/null
}

main() {
  [ -z "$PROMPT" ] && PROMPT="Mepo menu"

  if [ "$MEPO_MENUING" != "auto" ]; then # Custom override
    "$MEPO_MENUING"
  elif hascommand zenity; then # Use Zenity by default
    inputzenity
  else
    # Note: The following menuing methods have been deprecated, zenity
    #       is expected by default and the only officially supported 
    #       menuing method, this logic will likely be removed in
    #       a future release of mepo.
    if hascommand bemenu && pidof squeekboard >/dev/null; then # Phosh support
      inputbemenuphosh
    elif hascommand sxmo_dmenu_with_kb.sh; then # Sxmo support
      inputsxmodmenu
    elif hascommand bemenu && [ -n "$WAYLAND_DISPLAY" ]; then # Generic Wayland enviroment support
      inputbemenu
    elif hascommand dmenu && [ -n "$DISPLAY" ]; then # Generic X enviroment support
      inputdmenu
    elif hascommand vis-menu; then # Framebuffer support
      inputframebuffer
    elif hascommand zenity; then
      inputzenity
    else
      echo "Error determining MEPO_MENUING; no menuing system installed? Install bemenu, zenity, or dmenu" >&2
    fi
  fi
}

if [ -n "$1" ]; then "$@"; else main; fi
