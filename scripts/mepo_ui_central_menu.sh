#!/usr/bin/env sh

menuoptions() {
  echo "$PATH" | tr : '\n' | xargs ls -1 2>/dev/null | grep mepo_ | while read -r SCRIPT; do
    unset DISPLAYNAME
    eval "$(cat "$(which "$SCRIPT")" | grep -E '^(DISPLAYNAME|HOTKEY)=' )"
    [ -z "$DISPLAYNAME" ] && continue
    echo "$DISPLAYNAME ^ $SCRIPT ^ $HOTKEY"
  done | uniq | sort -d
}

main() {
  OPTIONS="$(menuoptions)"
  PRETTYNAMES="$(echo "$OPTIONS" | cut -d^ -f1 | uniq)"
  PICKED="$(
    echo -e "$PRETTYNAMES\n Close Menu" |
    PROMPT="Run Script" mepo_ui_helper_menu.sh
  )"
  [ -z "$PICKED" ] && return
  [ "$PICKED" = "Close Menu" ] && return
  RUNSCRIPT="$(echo "$OPTIONS" | grep "$PICKED" | head -n1 | cut -d^ -f2)"
  eval "$RUNSCRIPT"
}

if [ -n "$1" ]; then "$@"; else main; fi
