#!/usr/bin/env sh
DISPLAYNAME="漣 Update: Fontsize"

main() {
  echo prefset fontsize_ui "$(
    seq 12 30 |
    PROMPT="Font size" mepo_ui_helper_menu.sh
  );"
}

if [ -n "$1" ]; then "$@"; else main; fi
