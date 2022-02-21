#!/usr/bin/env sh
DISPLAYNAME="⊕ Bookmarks: Drop a pin"
HOTKEY=f

main() {
  PINNAME="$(
    PROMPT="Pin name" mepo_ui_helper_menu.sh
  )"

  echo "pin_add 3 0 $MEPO_CENTER_LAT $MEPO_CENTER_LON [$PINNAME] [$PINNAME];"
}

if [ -n "$1" ]; then "$@"; else main; fi
