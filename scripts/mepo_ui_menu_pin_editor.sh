#!/usr/bin/env sh
DISPLAYNAME="⊕ Pin editor: Edit, save, and restore pin metadata"
HOTKEY=f
ASYNC=1
DOC='
  Provides comprehensive pin editing via interactive menuing, allowing the
  user to add and remove pins,as well as edit pin metadata. Uses the
  `filedump` command functionality to extract pin data. Script is designed
  to be used asychronously via `shellpipe_async`.
'

mainloop() {
  # E.g. dump pin data to file & wait for complete
  TMPFILE="$(mktemp)"
  printf %b "filedump rp $TMPFILE;"
  while true; do
    cat "$TMPFILE" | grep -q . && break
    sleep 1
  done

  PINDATA="$(cat "$TMPFILE")"

  PINGROUP="$(echo "$PINDATA" | grep 'pin_groupactivate' | cut -d ' ' -f2 | tr -d ';')"
  LAT="$(echo "$PINDATA" | grep 'prefset_n lat' | cut -d ' ' -f3 | tr -d ';')"
  LON="$(echo "$PINDATA" | grep 'prefset_n lon' | cut -d ' ' -f3 | tr -d ';')"
  PINS="$(
    printf %b "$PINDATA" |
    grep '^pin_add' | 
    cut -d ' ' -f2- |
    tr -d ';]['
  )"

  CHOICE="$(
    printf %b "Close Menu\nAdd Pin (Group $PINGROUP)\nChange Group (Group $PINGROUP)\nSave pins to file\nLoad pins from file\n$PINS" |
    PROMPT="Pin editor" mepo_ui_helper_menu.sh
  )"

  if [ "$CHOICE" = "Save pins to file" ]; then
    [ -z "$XDG_CONFIG_HOME" ] && XDG_CONFIG_HOME=$HOME/.config
    mkdir -p $XDG_CONFIG_HOME/mepo
    FILEPATH="$(
      echo "$XDG_CONFIG_HOME/mepo/bookmarks" |
      PROMPT="Filepath" mepo_ui_helper_menu.sh
    )"
    printf %b "filedump p $FILEPATH;"
  elif [ "$CHOICE" = "Load pins from file" ]; then
    FILEPATH="$(
      PROMPT="Filepath" mepo_ui_helper_menu.sh
    )"
    printf %b "fileload $FILEPATH;"
  elif echo "$CHOICE" | grep -q "Change Group"; then
    GROUP="$(
      seq 0 9 | PROMPT="Activate Group" mepo_ui_helper_menu.sh
    )"
    printf %b "pin_groupactivate $GROUP;"
  elif echo "$CHOICE" | grep -q "Add Pin"; then
    PIN_TO_ADD="$(
      PROMPT="Pin handle" mepo_ui_helper_menu.sh
    )"
    printf %b "
      pin_add -1 0 $LAT $LON [$PIN_TO_ADD];
      pin_activate -1 [$PIN_TO_ADD];
    "
  elif [ "$CHOICE" = "Close Menu" ]; then
    exit
  elif printf %b "$CHOICE" | grep -q .; then
    PINHANDLE="$(echo $CHOICE | cut -d" " -f5)"
    PINGROUP="$(echo $CHOICE | cut -d" " -f1)"
    EDITCHOICE="$(
      printf %b "Delete pin\nUpdate coords\nUpdate metadata" | 
      PROMPT="Pin editor ($PINHANDLE)" mepo_ui_helper_menu.sh
    )"
    if [ "$EDITCHOICE" = "Delete pin" ]; then
      printf %b "pin_delete $PINGROUP $PINHANDLE;"
    elif [ "$EDITCHOICE" = "Update coords" ]; then
      NEWCORDS="$(
        printf %b "$LAT $LON (Cursor location)" | 
        PROMPT="New coordinates lat lon ($PINHANDLE)" mepo_ui_helper_menu.sh
      )"
      LAT="$(echo "$NEWCORDS" | cut -d' ' -f1)"
      LON="$(echo "$NEWCORDS" | cut -d' ' -f2)"
      printf %b "
        pin_activate $PINGROUP [$PINHANDLE];
        pin_meta $PINGROUP [$PINHANDLE] lat [$LAT];
        pin_meta $PINGROUP [$PINHANDLE] lon [$LON];
      "
    elif [ "$EDITCHOICE" = "Update metadata" ]; then
      METAKEY="$(PROMPT="($PINHANDLE): Metadata key" mepo_ui_helper_menu.sh)"
      METAVALUE="$(PROMPT="($PINHANDLE): Metadata value" mepo_ui_helper_menu.sh)"
      echo "
        pin_activate $PINGROUP [$PINHANDLE];
        pin_meta $PINGROUP [$PINHANDLE] [$METAKEY] [$METAVALUE];
      "
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
