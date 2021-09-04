#!/usr/bin/env sh
[ -z "$MEPO_MENU" ] && MEPO_MENU="dmenu -l 10 -w $(xdotool getactivewindow) -p"

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
    $MEPO_MENU "Search for Location" |
    sed 's/ /%20/g'
)"

nominatimsearch() {
  PINORCENTER="$1"

  RESULT="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY" |
      jq '.[] | "\(.display_name) \(.lat) \(.lon)" ' |
      $MEPO_MENU "Pick result"
  )"

  COORDS="$(
    echo "$RESULT" |
    grep -oE '(\-|\d|\.)+' |
    tail -n2 |
    tr "\n" " "
  )"

  echo "center_on_coords $COORDS;"
  [ "$PINORCENTER" = "pindrop" ] && echo "pin_add $COORDS [$RESULT];"
  exit 0
}

nominatimsearch $@
