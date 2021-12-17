#!/usr/bin/env sh

searchworldpickandgo() {
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
      mepo_ui_helper_menu.sh "Nominatim world search" |
      sed 's/ /%20/g'
  )"

  RESULT="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY" |
      jq '.[] | "\(.display_name) \(.lat) \(.lon)" ' |
      mepo_ui_helper_menu.sh "Pick result"
  )"

  COORDS="$(
    echo "$RESULT" |
    busybox grep -oE '(\-|\d|\.)+' |
    tail -n2 |
    tr "\n" " "
  )"

  [ -z "$COORDS" ] && {
      echo "Failed to determine COORDS from: $RESULT" >&2
      exit 1
  }

  echo "center_on_coords $COORDS;"
}

searchworldpickandgo
