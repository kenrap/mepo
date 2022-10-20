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
  PROPWIDTH=$1
  PROPHEIGHT=$2

  DIMS="$(
    xwininfo -tree -root |
      grep '("mepo" "mepo")' |
      awk '{$1=$1};1' |
      cut -d' ' -f1 |
      xargs xwininfo -id |
      grep -- -geometry |
      grep -oE '[0-9]+x[0-9]+'
  )"
  DIMW="$(echo $DIMS | cut -dx -f1 | xargs echo "$PROPWIDTH *" | bc | cut -d. -f1)"
  DIMH="$(echo $DIMS | cut -dx -f2 | xargs echo "$PROPHEIGHT *" | bc | cut -d. -f1)"

  if echo "$DIMW" | grep -Eq '[0-9]+' && echo "$DIMH" | grep -Eq '[0-9]+'; then
    echo "--width $DIMW --height $DIMH"
  fi
}

oskkeyboard() {
  # Sxmo keyboard open/close support
  hascommand sxmo_keyboard.sh && sxmo_keyboard.sh $1 > /dev/null
}

inputzenity() {
  if [ "$TEXTINPUT" = 1 ]; then
    oskkeyboard open
    zenity $(zenitydims 0.8 0.333) --title "Type input" --entry --text "$PROMPT"
    oskkeyboard close
  else
    OPTS="$(cat)\nType Custom"
    OPTS="$(printf %b "$OPTS" | tr -d \" | awk NF)"
    RESULT="$(
      echo "$OPTS" |
      xargs -d$'\n' zenity $(zenitydims 0.8 0.8) --title "Select an entry" --list --column=Selection --text "$PROMPT"
    )"
    if [ "$RESULT" = "Type Custom" ]; then
      TEXTINPUT=1 inputzenity
    else
      echo "$RESULT"
    fi
  fi
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
    echo "Error determining MEPO_MENUING & zenity dependency not installed." >&2
  fi
}

if [ -n "$1" ]; then "$@"; else main; fi
