#!/usr/bin/env sh
DISPLAYNAME="漣 Update: Zoom"
HOTKEY=z
DOC='
  Updates the zoom level based on user's input. Presents menuing to 
  pick from zoom levels between 1 and 16.
'

main() {
  echo prefset_n zoom "$(
    seq 1 16 |
    PROMPT="Zoom" mepo_ui_helper_menu.sh
  );"
}

if [ -n "$1" ]; then "$@"; else main; fi
