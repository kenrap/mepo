#!/usr/bin/env sh
queryprompt() {
  PROMPT="$1"
  
}

nominatimspecialphrasesfromwiki() {
  curl 'https://wiki.openstreetmap.org/wiki/Special:Export/Nominatim/Special_Phrases/EN' |
    grep '^| ' |
    grep -v '| -' |
    sed -E 's/\|\|.+$//g' |
    sed -E 's/^\| //g' |
    sort
}

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
      mepo_helper_menu.sh "Nominatim world search" |
      sed 's/ /%20/g'
  )"

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
  QUERY="$(
    nominatimspecialphrasesfromwiki |
      awk '{$1=$1};1' | 
      grep . | 
      mepo_helper_menu.sh "Nominatim search Bbox" |
      sed 's/ /%20/g'
  )"

  VIEWBOX="$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON,$MEPO_BR_LAT"
  RESULTS="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY&viewbox=$VIEWBOX&bounded=1&limit=50" |
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
