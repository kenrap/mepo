#!/usr/bin/env sh
DISPLAYNAME="Route via GraphHopper"

nominatimquerytargetmenu() {
  QUERY="$(
      echo "Enter nominatim query" |
      PROMPT="Nominatim search to route to" mepo_ui_helper_menu.sh |
      sed 's/ /%20/g'
  )"

  VIEWBOX="$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON,$MEPO_BR_LAT"
  RESULT="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY&viewbox=$VIEWBOX&bounded=1&limit=50" |
      jq '.[] | "\(.display_name) \(.lat) \(.lon)" ' |
      PROMPT="Pick result" mepo_ui_helper_menu.sh
  )"

  COORDS="$(
    echo "$RESULT" |
    busybox grep -oE '(\-|\d|\.)+' |
    tail -n2 |
    tr "\n" " "
  )"

  echo "$COORDS"
}

curlgraphhopper() {
  FROM="$1"
  DEST="$2"

  FROMLAT="$(echo $FROM | cut -d " " -f1)"
  FROMLON="$(echo $FROM | cut -d " " -f2)"
  DESTLAT="$(echo $DEST | cut -d " " -f1)"
  DESTLON="$(echo $DEST | cut -d " " -f2)"

  curl \
    -X POST \
    -H "Content-Type: application/json" \
    "https://graphhopper.com/api/1/route?key=$MEPO_GRAPHHOPPER_API_KEY" \
    -d '
      {
        "elevation": false,
        "points_encoded": false,
        "points": [
          ['$FROMLON','$FROMLAT'],
          ['$DESTLON','$DESTLAT']
        ],
        "vehicle": "car"
      }
    '
}

printpins() {
  RESPONSE="$1"

  COORDS="$(
    echo "$RESPONSE" | 
      jq '.paths[0].points.coordinates | .[] | join(" ")' | 
      tr -d '"' |
      awk '{ print $2, $1 }'
  )"

  INSTRUCTIONS="$(
    echo "$RESPONSE" | 
      jq '
        .paths[0].instructions | 
        .[] | 
        "\(.interval[0]) \(.interval[1]) \(.text) (for \(.time)ms and \(.distance) meters)"
      ' |
      tr -d '"'
  )"

  echo "pin_purge;"

  echo "$INSTRUCTIONS" | while read -r LINE; do
    INSTRUCTIONSTART="$(echo "$LINE" | cut -d " " -f1 | xargs -ISTART echo START + 1 |  bc)"
    STRUCTURALSTART="$(echo "$LINE" | cut -d " " -f1 | xargs -IEND echo END + 1 |  bc)"
    STRUCTURALEND="$(echo "$LINE" | cut -d " " -f2)"

    # Instructive pin
    echo $(
      printf "pin_add 0 "
      echo "$COORDS" | sed -n ${INSTRUCTIONSTART}p;
      printf "[";
      echo "$LINE" | cut -d ' ' -f3-;
      printf "];"
    )

    # Structural pins
    I="$STRUCTURALSTART"
    while [ "$I" -lt "$STRUCTURALEND" ]; do
      echo $(
        printf "pin_add 1 "
        echo "$COORDS" | sed -n ${I}p;
        printf " [structural - TODO];"
      )
      I="$(echo $I + 1 | bc)"
    done
  done
}

main() {
  MEPO_GRAPHHOPPER_DEFAULT_API_KEY="49343b56-0779-47d1-8ca3-0ea706ddc9c7"
  [ -z "$MEPO_GRAPHHOPPER_API_KEY" ] && MEPO_GRAPHHOPPER_API_KEY="$MEPO_GRAPHHOPPER_DEFAULT_API_KEY"
  printpins "$(
    curlgraphhopper \
      "$MEPO_C_LAT $MEPO_C_LON" \
      "$(nominatimquerytargetmenu)"
  )"
}

if [ -n "$1" ]; then "$@"; else main; fi
