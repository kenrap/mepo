#!/usr/bin/env sh
DISPLAYNAME="⊕ Pin editor: Edit, save, and restore pin metadata"
HOTKEY=f
ASYNC=1
# TODO, Sxmo's central menu generates shellpipe statements, for 0.5 syntax
# changes to support async items, pin script needs to be updated to support
# this

mainloop() {
  # E.g. dump pin data to file & wait for complete
  TMPFILE="$(mktemp)"
  printf %b "filedump rp $TMPFILE;"
  while true; do
    cat "$TMPFILE" | grep -q . && break
    sleep 1
  done

  PINDATA="$(cat "$TMPFILE")"

  LAT="$(echo "$PINDATA" | grep 'prefset_n lat' | cut -d ' ' -f3 | tr -d ';')"
  LON="$(echo "$PINDATA" | grep 'prefset_n lon' | cut -d ' ' -f3 | tr -d ';')"
  PINS="$(
    printf %b "$PINDATA" |
    grep '^pin_add' | 
    cut -d ' ' -f6- | 
    tr -d ';]['
  )"

  CHOICE="$(
    printf %b "Close Menu\nAdd Pin\nSave to file\nLoad from file\n$PINS" | 
    PROMPT="Pin editor" mepo_ui_helper_menu.sh
  )"

  if [ "$CHOICE" = "Save to file" ]; then
    FILEPATH="$(
      PROMPT="Filepath" mepo_ui_helper_menu.sh
    )"
    printf %b "filedump p $FILEPATH;"
  elif [ "$CHOICE" = "Load from file" ]; then
    FILEPATH="$(
      PROMPT="Filepath" mepo_ui_helper_menu.sh
    )"
    printf %b "fileload $FILEPATH;"
  elif [ "$CHOICE" = "Add Pin" ]; then
    PIN_TO_ADD="$(
      PROMPT="Pin handle" mepo_ui_helper_menu.sh
    )"
    printf %b "pin_add 0 0 $LAT $LON [$PIN_TO_ADD];"
  elif [ "$CHOICE" = "Close Menu" ]; then
    exit
  elif printf %b "$CHOICE" | grep -q .; then
    PINHANDLE="$CHOICE"
    EDITCHOICE="$(
      printf %b "Delete pin\nUpdate coords\nUpdate handle\nUpdate metadata" | 
      PROMPT="Pin editor ($PINHANDLE)" mepo_ui_helper_menu.sh
    )"
    if [ "$EDITCHOICE" = "Delete pin" ]; then
      printf %b "pin_delete $PINHANDLE;"
    elif [ "$EDITCHOICE" = "Update coords" ]; then
      printf %b # TODO
    elif [ "$EDITCHOICE" = "Update handle" ]; then
      printf %b # TODO
    elif [ "$EDITCHOICE" = "Update metadata" ]; then
      METAKEY="$(PROMPT="($PINHANDLE): Metadata key" mepo_ui_helper_menu.sh)"
      METAVALUE="$(PROMPT="($PINHANDLE): Metadata value" mepo_ui_helper_menu.sh)"
      echo "pin_meta -1 [$PINHANDLE] [$METAKEY] [$METAVALUE];"
    fi
  else
    exit
  fi
}

main() {
  while true; do
    mainloop
  done
}

if [ -n "$1" ]; then "$@"; else main; fi
