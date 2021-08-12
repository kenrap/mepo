#!/usr/bin/env sh
[ -z "$MEPO_MENU" ] && MEPO_MENU="dmenu -l 10 -w $(xdotool getactivewindow) -p"

BBOX="$MEPO_BR_LAT,$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON"

OPTIONS='
  Pizza        ["amenity"="restaurant"]["cuisine"="italian"]
  Indian       ["amenity"="restaurant"]["cuisine"="indian"]
  Supermarket  ["shop"="supermarket"]
  Coffeshop    ["amenity"="cafe"]
'

SCOPE="$(
  echo "$OPTIONS" |
    awk '{$1=$1};1' | 
    grep . | 
    $MEPO_MENU "Bbox POI Search" |
    cut -d ' ' -f2-
)"

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

echo 'pin_purge;'

echo "$JSON_RESULTS" |
  jq '.elements | .[] | "\(.lat) \(.lon) \(.tags.name)" ' |
  tr -d \" |
  grep -vE 'null$' |
  grep -vE '^null' |
  awk -F' ' '{print $1 " " $2 " [" $3 " " $4 " " $5 " " $6 " " $7 " " $8 "]"}' |
  sed 's/[^[:print:]]//g' |
  sed "s/'/\\\'/g" |
  xargs -ID echo 'pin_add D;'
