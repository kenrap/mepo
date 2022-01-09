#!/usr/bin/env sh
DISPLAYNAME="POI Search: via Nominatim"

nominatimspecialphrasesfromwiki() {
  curl 'https://wiki.openstreetmap.org/wiki/Special:Export/Nominatim/Special_Phrases/EN' |
    grep '^| ' |
    grep -v '| -' |
    sed -E 's/\|\|.+$//g' |
    sed -E 's/^\| //g' |
    sort
}

main() {
  QUERY="$(
    nominatimspecialphrasesfromwiki |
      awk '{$1=$1};1' | 
      grep . | 
      PROMPT="Nominatim search Bbox" mepo_ui_helper_menu.sh |
      sed 's/ /%20/g'
  )"

  VIEWBOX="$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON,$MEPO_BR_LAT"
  JSONRESULTS="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY&viewbox=$VIEWBOX&bounded=1&limit=50&extratags=1"
  )"
  RESULTS="$(
    echo "$JSONRESULTS" |
    jq '.[] | "\(.lat) \(.lon) \(.display_name)"'
  )"

  echo "
    pin_groupprefset 0 ordered 0;
    pin_groupprefset 0 active 1;
    pin_purge;
  "


  echo "$RESULTS" |
    grep . |
    tr -d \" |
    grep -vE 'null$' |
    grep -vE '^null' |
    awk -F' ' '{lat=$1; lon=$2; $1=""; $2=""; gsub(/^[ \t]+/,"",$0); print lat " " lon " [" $0 "]"}' |
    sed 's/[^[:print:]]//g' |
    sed "s/'/\\\'/g" |
    xargs -ID echo 'pin_add 0 D;'
}

if [ -n "$1" ]; then "$@"; else main; fi
