#!/usr/bin/env sh
DISPLAYNAME="Update: Zoom"

main() {
  echo prefset zoom "$(
    seq 1 16 |
    PROMPT="Zoom" mepo_ui_helper_menu.sh
  );"
}

if [ -n "$1" ]; then "$@"; else main; fi
