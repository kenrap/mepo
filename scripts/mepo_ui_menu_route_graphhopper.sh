#!/usr/bin/env sh
set -o pipefail
DISPLAYNAME=" Route: via GraphHopper"
HOTKEY=R
DOC='
  Allows user to route between the first two pins in the active pingroup
  via the publicly accessible GraphHopper instance. Change variables in
  the presented select list to toggle parameters.
'
[ -z "$MEPO_ENDPOINT_NOMINATIM_SEARCH" ] && MEPO_ENDPOINT_NOMINATIM_SEARCH="https://nominatim.openstreetmap.org/search"
[ -z "$MEPO_ENDPOINT_GRAPHHOPPER_ROUTE" ] && MEPO_ENDPOINT_GRAPHHOPPER_ROUTE="https://graphhopper.com/api/1/route"
[ -z "$MEPO_APIKEY_GRAPHHOPPER" ] && MEPO_APIKEY_GRAPHHOPPER="49343b56-0779-47d1-8ca3-0ea706ddc9c7"
[ -z "$MEPO_GRAPHHOPPER_DEFAULTS" ] && MEPO_GRAPHHOPPER_DEFAULTS="From Geocoordinate|GEOCORDFROM
To Geocoordinate|GEOCORDTO
Mode|car"


errdie() {
  zenity --error --text "$1"
  exit 1
}

errcheckhastwopins() {
  NPINS="$(
    cat $XDG_CACHE_HOME/mepo/shellpipe_savestate.json |
      jq "[.[] | select(.cmd == \"pin_add\" and .args.group == $MEPO_PINGROUPACTIVE)] | length"
  )"

  ERR_PINS="Must have atleast 2 pins in active pin group to route between!
    - Note: Please drop atleast two pins on the map to route between
    - Note: You can use the drop pin item in the central menu (or press f)
  "
  [ "$NPINS" -lt "2" ] && errdie "$ERR_PINS"
}

gettablevals() {
  JSONPIN0="$(
    cat $XDG_CACHE_HOME/mepo/shellpipe_savestate.json |
      jq "[.[] | select(.cmd == \"pin_add\" and .args.group == $MEPO_PINGROUPACTIVE)] | first"
  )"
  JSONPIN1="$(
    cat $XDG_CACHE_HOME/mepo/shellpipe_savestate.json |
      jq "[.[] | select(.cmd == \"pin_add\" and .args.group == $MEPO_PINGROUPACTIVE)] | last"
  )"
  COORDFROM="$(echo "$JSONPIN0" | jq '(.args.lat|tostring) + ", " + (.args.lon|tostring)' |tr -d '"')"
  COORDTO="$(echo "$JSONPIN1" | jq '(.args.lat|tostring) + ", " + (.args.lon|tostring)' |tr -d '"')"
  echo "$MEPO_GRAPHHOPPER_DEFAULTS" | sed "s#GEOCORDFROM#$COORDFROM#g" | sed "s#GEOCORDTO#$COORDTO#g"
}

mapnlvalstojson() {
  jq -nR 'reduce inputs as $line ({}; .[$line] = input)'
}

curlgraphhopper() {
  MODE="$1"
  FROM="$2"
  DEST="$3"

  FROMLAT="$(echo "$FROM" | cut -d "," -f1)"
  FROMLON="$(echo "$FROM" | cut -d "," -f2)"
  DESTLAT="$(echo "$DEST" | cut -d "," -f1)"
  DESTLON="$(echo "$DEST" | cut -d "," -f2)"

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
  GRAPHHOPPER_ARGSPROMPT_TEXT="Graphhopper Route
  - You may edit the route parameters below.
  - Valid modes are: walk, bike, car
  - Rows edited must be selected before hitting 'Route'\n\nParameters:"

  errcheckhastwopins
  JSONBASE="$(gettablevals | tr '|' '\n' | mapnlvalstojson)"
  JSONSELECTRESULT="$(
    gettablevals |
      awk -F '|' '{printf "\"%s\" \"%s\" ", $1, $2}' |
      xargs zenity \
        $(mepo_ui_helper_menu.sh zenitydims 0.8 0.8) \
        --ok-label Route --list --editable --multiple --text "$GRAPHHOPPER_ARGSPROMPT_TEXT" --print-column ALL \
        --column "Parameter" \
        --column "Value" |
      tr '|' '\n' |
      mapnlvalstojson
  )"
  JSONRAWVALS="$(echo "[$JSONBASE, $JSONSELECTRESULT]" | jq add)"
  MODE="$(echo "$JSONRAWVALS" | jq '.Mode' | tr -d '"')"
  LOCFROM="$(echo "$JSONRAWVALS" | jq '."From Geocoordinate"' | tr -d '"')"
  LOCTO="$(echo "$JSONRAWVALS" | jq '."To Geocoordinate"' | tr -d '"')"

  printpins "$(curlgraphhopper "$MODE" "$LOCFROM" "$LOCTO")"
}

if [ -n "$1" ]; then "$@"; else main; fi
