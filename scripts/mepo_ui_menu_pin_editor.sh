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

  echo "$PINDATA" | PROMPT="Pin editor" mepo_ui_helper_menu.sh
}

if [ -n "$1" ]; then "$@"; else main; fi
