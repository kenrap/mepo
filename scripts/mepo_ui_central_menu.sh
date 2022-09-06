#!/usr/bin/env sh
DOC='
  Generates listing central menu for mobile usage. Essentially just greps all
  scripts named mepo_* and any resulting script that has DISPLAYNAME variable
  is shown in the menu.
'

menuoptions() {
  echo "$PATH" | tr : '\n' | xargs ls -1 2>/dev/null | grep mepo_ | while read -r SCRIPT; do
    unset DISPLAYNAME
    ASYNC=0
    eval "$(cat "$(which "$SCRIPT")" | grep -E '^(DISPLAYNAME|HOTKEY|ASYNC)=' )"
    [ -z "$DISPLAYNAME" ] && continue
    echo "$DISPLAYNAME ^ $SCRIPT ^ $HOTKEY ^ $ASYNC"
  done | uniq | sort -d
}

main() {
  OPTIONS="$(menuoptions)"
  PRETTYNAMES="$(echo "$OPTIONS" | cut -d^ -f1 | uniq)"
  PICKED="$(
    printf %b "$PRETTYNAMES\n Close Menu" |
    PROMPT="Run Script" mepo_ui_helper_menu.sh
  )"
  [ -z "$PICKED" ] && return
  [ "$PICKED" = "Close Menu" ] && return
  RUNSCRIPT="$(echo "$OPTIONS" | grep "$PICKED" | head -n1 | cut -d^ -f2)"
  ASYNC="$(echo "$OPTIONS" | grep "$PICKED" | head -n1 | cut -d^ -f4)"

  # E.g. if script is tagged with variable ASYNC, run the script
  # as an asynchronous shellpipe (e.g. wont lock UI etc).
  #
  # Otherwise, runs script directly (not as a shellpipe since that would
  # need to wait for this script (which is also run from shellpipe) to return
  # but directly evals the script
  if echo "$ASYNC" | grep -q 1; then
    echo "shellpipe_async 99 $RUNSCRIPT;"
  else
    eval "$RUNSCRIPT"
  fi
}

if [ -n "$1" ]; then "$@"; else main; fi
