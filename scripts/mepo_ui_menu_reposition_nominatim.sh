#!/usr/bin/env sh
DISPLAYNAME=" Relocate map: via search"
HOTKEY=g
DOC='
  Repositions the map latitude and longitude based on a Nominatim search
  query. Presents menuing to prompt user for input location and pick from
  Nominatim results.
'

err() {
  echo "$@" >&2
  exit 1
}

main() {
  OPTIONS='
    Cancel
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
      PROMPT="Nominatim Relocate" mepo_ui_helper_menu.sh |
      sed 's/ /%20/g'
  )"

  [ "$QUERY" = "Cancel" ] && exit
  echo "$QUERY" | grep -q . || err "Blank search query"

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

  LAT="$(echo "$COORDS" | cut -d ' ' -f1)"
  LON="$(echo "$COORDS" | cut -d ' ' -f2)"
  echo "prefset_n lat $LAT;"
  echo "prefset_n lon $LON;"
}

if [ -n "$1" ]; then "$@"; else main; fi
