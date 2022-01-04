#!/usr/bin/env sh
DISPLAYNAME="Route via GraphHopper"

errexit() {
  echo "$1" >&2
  exit 1
}

nominatimquerytargetmenu() {

  COORDS=""

  while ! echo "$COORDS" | grep -Eq "[-0-9.]+[ ]+[-0-9.]+"; do
    QUERY="$(
        echo -e "centerpoint\nOr enter nominatim query location" |
        PROMPT="$1" mepo_ui_helper_menu.sh |
        sed 's/ /%20/g'
    )"
    [ "$QUERY" = "centerpoint" ] && COORDS="$MEPO_C_LAT $MEPO_C_LON" && break

    VIEWBOX="$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON,$MEPO_BR_LAT"
    RESULT="$(
      curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY&viewbox=$VIEWBOX&bounded=1&limit=50" |
        jq '.[] | "\(.display_name) \(.lat) \(.lon)" '
    )"

    if ! echo "$RESULT" | awk NF | grep -Eq .; then
      echo "No results - press any key!" | PROMPT="No results!" mepo_ui_helper_menu.sh 
      continue
    fi

    COORDS="$(
      echo "$RESULT" | 
      PROMPT="Pick result" mepo_ui_helper_menu.sh |
      busybox grep -oE '[-0-9.]+' |
      tail -n2 |
      tr "\n" " "
    )"
  done

  echo "$COORDS"
}

curlgraphhopper() {
  MODE="$1"
  FROM="$2"
  DEST="$3"

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
        "vehicle": "'$MODE'"
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

  MODE="$(
    echo -e "car\nbike\nfoot" |
    PROMPT="Route mode" mepo_ui_helper_menu.sh
  )"
  echo "$MODE" | grep -qE "^(car|bike|foot)" || errexit "Unsupported route mode"

  LOCFROM="$(nominatimquerytargetmenu "Route from")"
  [ -z "$LOCFROM" ] && errexit "Failed to determine coordinates to route to"

  LOCTO="$(nominatimquerytargetmenu "Route to")"
  [ -z "$LOCTO" ] && errexit "Failed to determine coordinates to route to"

  printpins "$(curlgraphhopper "$MODE" "$LOCFROM" "$LOCTO")"
}

if [ -n "$1" ]; then "$@"; else main; fi
