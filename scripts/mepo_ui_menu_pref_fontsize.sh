#!/usr/bin/env sh
DISPLAYNAME="⚙ Update: Fontsize"
HOTKEY=Z
DOC='
  Updates the fontsize of the UI prompting the user for the input size.
  Presents menuing prefilled between sizes 12 and 30.
'

main() {
  echo '[{
    "cmd": "prefset_n",
    "args": {
      "pref": "fontsize_ui",
      "value": '$(
        seq 12 30 |
        PROMPT="Font size" mepo_ui_helper_menu.sh
      )'
    }
  }]'
}

if [ -n "$1" ]; then "$@"; else main; fi
