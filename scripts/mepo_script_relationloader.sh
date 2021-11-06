#!/usr/bin/env sh

RELATIONS="
  NYC Subway A: 9727210
  NYC Subway C: 366775
  NYC Subway E: 366776
  NYC Subway 1: 364630
  NYC Subway 2: 9655663
  NYC Subway 3: 366784
  Mexico City 1: 443191
  Mexico City 2: 443229
  Mexico City 3: 443206 
"

RELATIONID="$(
  echo "$RELATIONS" |
    awk '{$1=$1};1' | 
    grep . | 
    mepo_helper_menu.sh "Relation (or enter custom relation id):" |
    grep -oE "[0-9^]+$"
)"

JSON_RESULTS="$(
  curl  "https://lz4.overpass-api.de/api/interpreter" --data-raw "data=$(
    echo '
      [out:json][timeout:25];
      rel(RELATIONID);
      node(r);
      out+body;
      >;
      out+skel+qt;
    ' | sed "s/RELATIONID/$RELATIONID/g"
  )"
)"

echo "pin_purge;"
echo "$JSON_RESULTS" |
  jq '.elements | .[] | "\(.lat) \(.lon) \(.tags.name)" ' |
  tr -d \" |
  grep -vE 'null$' |
  grep -vE '^null' |
  awk -F' ' '{lat=$1; lon=$2; $1=""; $2=""; gsub(/^[ \t]+/,"",$0); print lat " " lon " [" $0 "]"}' |
  sed 's/[^[:print:]]//g' |
  sed "s/'/\\\'/g" |
  xargs -ID echo 'pin_add D;'

