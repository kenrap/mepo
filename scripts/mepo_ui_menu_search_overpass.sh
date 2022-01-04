#!/usr/bin/env sh
DISPLAYNAME="POI Search via Overpass"

OPTIONS='
  Pizza         ["amenity"="restaurant"]["cuisine"="italian"]
  Indian        ["amenity"="restaurant"]["cuisine"="indian"]
  Supermarket   ["shop"="supermarket"]
  Coffeshop     ["amenity"="cafe"]
  Supermarket   ["shop"="supermarket"]
  Grocery       ["shop"="grocery"]
'

main() {
  SCOPE="$(
    echo "$OPTIONS" |
      awk '{$1=$1};1' | 
      grep . | 
      PROMPT="Bbox POI Search" mepo_ui_helper_menu.sh |
      cut -d ' ' -f2-
  )"
  [ -z "$SCOPE" ] && exit 0

  BBOX="$MEPO_BR_LAT,$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON"
  JSON_RESULTS="$(
    curl  "https://lz4.overpass-api.de/api/interpreter" --data-raw "data=$(
      echo '
        [out:json][timeout:25];
        (
          nodeSCOPE(BBOX);
          waySCOPE(BBOX);
          relationSCOPE(BBOX);
        );
        out+body;
        >;
        out+skel+qt;
      ' | sed "s/BBOX/$BBOX/g" | sed "s/SCOPE/$SCOPE/g"
    )"
  )"

  echo "
    pin_groupprefset 0 ordered 0;
    pin_groupprefset 0 active 1;
    pin_purge;
  "

  echo "$JSON_RESULTS" |
    jq '.elements | .[] | "\(.lat) \(.lon) \(.tags.name)" ' |
    tr -d \" |
    grep -vE 'null$' |
    grep -vE '^null' |
    awk -F' ' '{lat=$1; lon=$2; $1=""; $2=""; gsub(/^[ \t]+/,"",$0); print lat " " lon " [" $0 "]"}' |
    sed 's/[^[:print:]]//g' |
    xargs -ID echo 'pin_add 0 D;'
}

if [ -n "$1" ]; then "$@"; else main; fi
