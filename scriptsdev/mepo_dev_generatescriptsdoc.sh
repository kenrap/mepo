#!/usr/bin/env sh
cd "$(realpath "$(dirname "$0")")"/.. || exit 1

SCRIPTS="$(ls -1 scripts/ | grep mepo_ui_menu_)"

for SCRIPT in $SCRIPTS; do
  source scripts/"$SCRIPT" nonexistingfn
  DISPLAYNAMECLEAN="$(echo "$DISPLAYNAME" | tr -cd '[:print:]' | sed 's/^ *//g')"
  DOCCLEAN="$(echo "$DOC" | sed 's/^ *//g' | tr '\n' ' ')"
  echo "- **${DISPLAYNAMECLEAN}** ($HOTKEY): $DOCCLEAN"
done
