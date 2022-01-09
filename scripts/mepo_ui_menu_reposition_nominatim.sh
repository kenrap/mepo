#!/usr/bin/env sh
DISPLAYNAME="Relocate map: via search"

main() {
  OPTIONS='
    Amsterdam
    Paris
    NYC
    Boston
    India
    Romania
    Iraq
  '

  QUERY="$(
    echo "$OPTIONS" |
      awk '{$1=$1};1' | 
      grep . | 
      PROMPT="Nominatim world search" mepo_ui_helper_menu.sh |
      sed 's/ /%20/g'
  )"

  RESULT="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY" |
      jq '.[] | "\(.display_name) \(.lat) \(.lon)" ' |
      PROMPT="Pick result" mepo_ui_helper_menu.sh 
  )"

  COORDS="$(
    echo "$RESULT" |
    grep -oE '[-0-9.]+' |
    tail -n2 |
    tr "\n" " "
  )"

  [ -z "$COORDS" ] && {
      echo "Failed to determine COORDS from: $RESULT" >&2
      exit 1
  }

  echo "center_on_coords $COORDS;"
}

if [ -n "$1" ]; then "$@"; else main; fi

