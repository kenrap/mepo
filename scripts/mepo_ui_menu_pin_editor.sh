#!/usr/bin/env sh
DISPLAYNAME="⊕ Pin editor: Edit, save, and restore pin metadata"
HOTKEY=f
ASYNC=1
# TODO, Sxmo's central menu generates shellpipe statements, for 0.5 syntax
# changes to support async items, pin script needs to be updated to support
# this

main() {
  # E.g. dump pin data to file & wait for complete
  TMPFILE="$(mktemp)"
  echo "filedump p $TMPFILE;"
  while true; do
    cat "$TMPFILE" | grep -q . && break
    sleep 1
  done

  PINDATA="$(cat "$TMPFILE")"

  PINS="$(
    echo "$PINDATA" |
    grep '^pin_add' | 
    cut -d ' ' -f6- | 
    tr -d ';]['
  )"

  CHOICE="$(
    printf %b "Add Pin\nSave to file\nLoad from file\n$PINS" | 
    PROMPT="Pin editor" mepo_ui_helper_menu.sh
  )"

  if [ "$CHOICE" = "Cancel" ]; then
    return
  elif [ "$CHOICE" = "Add Pin" ]; then
    PIN_TO_ADD="$(
      PROMPT="Pin handle" mepo_ui_helper_menu.sh
    )"
    echo "pin_add 0 0 $MEPO_CENTER_LAT $MEPO_CENTER_LON [$PIN_TO_ADD];"
  else
    echo "Delete pin\nUpdate coords\nUpdate handle"
    # Update coords
    # Update handle
    # Edit metadata
  fi
}

if [ -n "$1" ]; then "$@"; else main; fi
