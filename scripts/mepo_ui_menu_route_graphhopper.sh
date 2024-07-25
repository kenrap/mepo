#!/usr/bin/env sh
DISPLAYNAME=" Route: via GraphHopper"
HOTKEY=R
DOC='
  Allows user to determine a route between two points via the publicly
  accessible GraphHopper instance. Presents menuing to prompt user for origin
  and destination points. The cursor (e.g. the position of the mouse or on
  mobile the last clicked point - e.g. in case of click-hold functionality)
  and the centerpoint (where the crosshair is) may be used as origin or
  destination points as an alternative to named entries. Named entry searches
  use Nominatim to lookup the user input query. Resulting route is placed
  into pin group 7 as an ordered pin group wherein instructional pins show
  each direction in the route.
'
[ -z "$MEPO_ENDPOINT_NOMINATIM_SEARCH" ] && MEPO_ENDPOINT_NOMINATIM_SEARCH="https://nominatim.openstreetmap.org/search"
[ -z "$MEPO_ENDPOINT_GRAPHHOPPER_ROUTE" ] && MEPO_ENDPOINT_GRAPHHOPPER_ROUTE="https://graphhopper.com/api/1/route"
[ -z "$MEPO_APIKEY_GRAPHHOPPER" ] && MEPO_APIKEY_GRAPHHOPPER="49343b56-0779-47d1-8ca3-0ea706ddc9c7"

errexit() {
  echo "$1" >&2
  exit 1
}

nominatimquerytargetmenu() {
  COORDS=""

  while ! echo "$COORDS" | grep -Eq "[-0-9.]+[ ]+[-0-9.]+"; do
    QUERY="$(
        printf %b "centerpoint\ncursor" |
        PROMPT="$1 (Nominatim search)" mepo_ui_helper_menu.sh |
        sed 's/ /%20/g'
    )"
    [ "$QUERY" = "centerpoint" ] && COORDS="$MEPO_CENTER_LAT $MEPO_CENTER_LON" && break
    [ "$QUERY" = "cursor" ] && COORDS="$MEPO_CURSOR_LAT $MEPO_CURSOR_LON" && break


    VIEWBOX="$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON,$MEPO_BR_LAT"
    RESULT="$(
      curl -Ss "${MEPO_ENDPOINT_NOMINATIM_SEARCH}?format=json&q=$QUERY&viewbox=$VIEWBOX&bounded=1&limit=50" |
        jq '.[] | "\(.display_name) \(.lat) \(.lon)" '
    )"

    if ! echo "$RESULT" | awk NF | grep -Eq .; then
      echo "No results - press any key!" | PROMPT="No results!" mepo_ui_helper_menu.sh  > /dev/null
      continue
    fi

    COORDS="$(
      echo "$RESULT" | 
      PROMPT="Pick result" mepo_ui_helper_menu.sh |
      grep -oE '[-0-9.]+' |
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

  FROMLAT="$(echo "$FROM" | cut -d " " -f1)"
  FROMLON="$(echo "$FROM" | cut -d " " -f2)"
  DESTLAT="$(echo "$DEST" | cut -d " " -f1)"
  DESTLON="$(echo "$DEST" | cut -d " " -f2)"

  curl -Ss \
    -X POST \
    -H "Content-Type: application/json" \
    "${MEPO_ENDPOINT_GRAPHHOPPER_ROUTE}?key=$MEPO_APIKEY_GRAPHHOPPER" \
    -d '
      {
        "elevation": false,
        "points_encoded": false,
        "points": [
          ['"$FROMLON"','"$FROMLAT"'],
          ['"$DESTLON"','"$DESTLAT"']
        ],
        "vehicle": "'"$MODE"'"
      }
    '
}

printpins() {
  RESPONSE="$1"

  PRECMDS='[
      {"cmd": "prefset_n", "args": {"pref": "pingroup_7_ordered", "value": 1}},
      {"cmd": "pin_groupactivate", "args": {"group": 7}},
      {"cmd": "pin_purge", "args": {}}
  ]'

  PINADDS="$(
    echo "$RESPONSE" |
      jq '[
        . as $root | 
        [.paths[0].instructions | .[] | {"\(.interval[0])" : . }] | add as $instructions | 
        $root.paths[0].points.coordinates |
        to_entries |
        map({coords:.value, idx:"\(.key)", instruction:$instructions["\(.key)"]}) | 
        .[] | 
        if(.instruction != null) then 
          [
            {"cmd": "pin_add", "args": {"lat": .coords[1], "lon": .coords[0], "handle": .idx}},
            {"cmd": "pin_meta", "args": {"key": "name", "value": .instruction.text, "handle": .idx}},
            {"cmd": "pin_meta", "args": {"key": "time", "value": ((.instruction.time / 1000 / 60 | tostring) + " minutes"), "handle": .idx}},
            {"cmd": "pin_meta", "args": {"key": "distance", "value": ((.instruction.distance | tostring) + "km"), "handle": .idx}}
          ]
          else
          [
            {"cmd": "pin_add", "args": {"lat": .coords[1], "lon": .coords[0], "handle": "", "structural": 1}}
          ]
        end
      ] | flatten'
  )"

  echo "[$PRECMDS, $PINADDS]" | jq  '[.[][]]'
}

main() {
  MODE="$(
    printf %b "car\nbike\nfoot" |
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
