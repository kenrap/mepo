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
  elif [ "$CHOICE" = "Save to file" ]; then
    FILEPATH="$(
      PROMPT="Filepath" mepo_ui_helper_menu.sh
    )"
    echo "filedump p $FILEPATH;"
  elif [ "$CHOICE" = "Load from file" ]; then
    FILEPATH="$(
      PROMPT="Filepath" mepo_ui_helper_menu.sh
    )"
    echo "fileload $FILEPATH;"
  elif [ "$CHOICE" = "Add Pin" ]; then
    PIN_TO_ADD="$(
      PROMPT="Pin handle" mepo_ui_helper_menu.sh
    )"
    echo "pin_add 0 0 $MEPO_CENTER_LAT $MEPO_CENTER_LON [$PIN_TO_ADD];"
  elif echo "$CHOICE" | grep -q .; then
    PINHANDLE="$CHOICE"
    EDITCHOICE="$(
      printf %b "Delete pin\nUpdate coords\nUpdate handle\nUpdate metadata" | 
      PROMPT="Pin editor ($PINHANDLE)" mepo_ui_helper_menu.sh
    )"
    if [ "$EDITCHOICE" = "Delete pin" ]; then
      echo "pin_delete $PINHANDLE;"
    elif [ "$EDITCHOICE" = "Update coords" ]; then
      echo # TODO
    elif [ "$EDITCHOICE" = "Update handle" ]; then
      echo # TODO
    elif [ "$EDITCHOICE" = "Update metadata" ]; then
      echo # TODO
    fi
  fi
}

if [ -n "$1" ]; then "$@"; else main; fi
