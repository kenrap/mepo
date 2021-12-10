#!/usr/bin/env sh
OPTIONS='
  Amsterdam
  Paris
  NYC
  Boston
  India
  Romania
  Iraq
'

queryprompt() {
  PROMPT="$1"
  
  echo "$OPTIONS" |
    awk '{$1=$1};1' | 
    grep . | 
    mepo_helper_menu.sh "$PROMPT" |
    sed 's/ /%20/g'
}

searchworldpickandgo() {
  QUERY="$(queryprompt "Nominatim world search")"

  RESULT="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY" |
      jq '.[] | "\(.display_name) \(.lat) \(.lon)" ' |
      mepo_helper_menu.sh "Pick result"
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

searchbboxandpindrops() {
  QUERY="$(queryprompt "Nominatim Bbox search")"

  VIEWBOX="$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON,$MEPO_BR_LAT"
  echo curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY&viewbox=$VIEWBOX&bounded=1" > /home/m/debugq
  RESULTS="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY&viewbox=$VIEWBOX&bounded=1" |
      jq '.[] | "\(.lat) \(.lon) \(.display_name)" '
  )"

  echo "$RESULTS" > /home/m/debug

  echo "pin_purge"
  echo "$RESULTS" |
    grep . |
    tr -d \" |
    grep -vE 'null$' |
    grep -vE '^null' |
    awk -F' ' '{lat=$1; lon=$2; $1=""; $2=""; gsub(/^[ \t]+/,"",$0); print lat " " lon " [" $0 "]"}' |
    sed 's/[^[:print:]]//g' |
    sed "s/'/\\\'/g" |
    xargs -ID echo 'pin_add D;'
}

"$@"
