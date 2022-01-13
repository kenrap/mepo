#!/usr/bin/env sh

menuoptions() {
  for SCRIPT in $(echo "$PATH" | tr : '\n' | xargs ls -1 2>/dev/null | grep -E ^mepo_); do
    unset DISPLAYNAME
    . "$SCRIPT" nonexistentfn 2> /dev/null
    [ -z "$DISPLAYNAME" ] && continue
    echo "$DISPLAYNAME ^ $SCRIPT"
  done | uniq | sort
}

main() {
  OPTIONS="$(menuoptions)"
  PRETTYNAMES="$(echo "$OPTIONS" | cut -d^ -f1)"
  PICKED="$(
    echo "$PRETTYNAMES" | 
    PROMPT="Run Script" mepo_ui_helper_menu.sh
  )"
  [ -z "$PICKED" ] && return
  RUNSCRIPT="$(echo "$OPTIONS" | grep "$PICKED" | cut -d^ -f2)"
  eval "$RUNSCRIPT"
}

if [ -n "$1" ]; then "$@"; else main; fi
