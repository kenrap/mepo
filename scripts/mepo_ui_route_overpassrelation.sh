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
    mepo_ui_helper_menu.sh "Relation (or enter custom relation id):" |
    grep -oE "[0-9^]+$"
)"

JSON_RESULTS="$(
  curl  "https://lz4.overpass-api.de/api/interpreter" --data-raw "data=$(
    echo '
      [out:json][timeout:25];
      rel(RELATIONID);
      (._;>>;);
      out+body;
      >;
      out+skel+qt;
    ' | sed "s/RELATIONID/$RELATIONID/g"
  )"
)"


# E.g. get order of reference ids in relation
SORTED_REFS="$(
  echo "$JSON_RESULTS" | 
    jq '.elements | .[] | select(.type=="relation") | .members | .[].ref'
)"
FILEREFSORDER="$(mktemp)"
echo "$SORTED_REFS" > "$FILEREFSORDER"

# E.g. get all nodes with tags
NODES="$(
  echo "$JSON_RESULTS" |
    jq '.elements | .[] | "\(.lat) \(.lon) \(.id) \(.tags.name)" ' |
    tr -d \" |
    grep -vE 'null$' |
    grep -vE '^null' |
    awk -F' ' '{lat=$1; lon=$2; id=$3; $1=""; $2=""; $3=""; gsub(/^[ \t]+/,"",$0); print id " " lat " " lon " [" $0 "]"}'
)"
FILENODES="$(mktemp)"
echo "$NODES" > "$FILENODES"

echo "pin_purge;"
# Sort nodes based on reference ids, delete first item, only show printable chars
# and pin add each entry

awk 'FNR==NR {x2[$1] = $0; next} $1 in x2 {print x2[$1]}' "$FILENODES" "$FILEREFSORDER" |
  cut -f 2- -d ' ' |
  sed 's/[^[:print:]]//g' |
  sed "s/'/\\\'/g" |
  xargs -ID echo 'pin_add 0 D;'
