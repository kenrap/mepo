#!/usr/bin/env sh
DISPLAYNAME="⊙ Location Pin: Center on user location"
HOTKEY=x
DOC='
  Determines the user location via GPSD, Geoclue, or Mozilla
  Location services. When provided with no argument runs the function
  `droppinactivateandcenter` which both drops a pin on the map and
  centers the map. Meanwhile the function `droppin` can be used in
  isolation to only drop a pin on the map in pingroup 6. This script 
  may be used synchronously or asynchronously; within the 
  default config `droppin` is used asynchronously via `shellpipe_async`.
'
[ -z "$MEPO_USERPIN_ENABLED" ] && MEPO_USERPIN_ENABLED="1"
[ -z "$MEPO_ENDPOINT_MLS" ] && MEPO_ENDPOINT_MLS="https://location.services.mozilla.com/v1/geolocate"
[ -z "$MEPO_APIKEY_MLS" ] && MEPO_APIKEY_MLS="9a418f3c-364a-418a-85e8-1bde733f0c88"
[ -z "$MEPO_TIMEOUT_GEOCLUE" ] && MEPO_TIMEOUT_GEOCLUE="10"
[ -z "$MEPO_GEOLOCATE_COORDSVIAMETHOD" ] && MEPO_GEOLOCATE_COORDSVIAMETHOD="coordsviageoclue"

coordsviamls() {
  MLSRESULT="$(curl -Ss "${MEPO_ENDPOINT_MLS}?key=$MEPO_APIKEY_MLS")"
  LAT="$(echo "$MLSRESULT" | jq '.location.lat')"
  LON="$(echo "$MLSRESULT" | jq '.location.lng')"
  echo "$LAT $LON"
}

coordsviageoclue() {
  supportsgeoclue || return 1

  /usr/libexec/geoclue-2.0/demos/agent > /dev/null &
  AGENTPID=$!
  LC_NUMERIC=en_US.UTF-8 /usr/libexec/geoclue-2.0/demos/where-am-i -t $MEPO_TIMEOUT_GEOCLUE |
    grep -E "Latitude|Longitude:" -m2 |
    cut -d: -f2 |
    tr -d "° " |
    tr "\n" " "
  kill -9 $AGENTPID
}

supportsgeoclue() {
  stat /usr/libexec/geoclue-2.0/demos/agent > /dev/null 2> /dev/null &&
  stat /usr/libexec/geoclue-2.0/demos/where-am-i > /dev/null 2> /dev/null
}

coordsviagpsd() {
  # On pmOS: sudo /etc/gpsd/device-hook "" ACTIVATE
  gpspipe -w -n 10 2> /dev/null | grep -m 1 TPV | jq '.lat, .lon' | tr '\n' ' '
}

iscoords() {
  echo "$1" | grep -qE '[0-9.\-]+ [0-9.\-]+'
}

getcoords() {
  # Use method set in ENV var MEPO_GEOLOCATE_COORDSVIAMETHOD
  COORDS="$($MEPO_GEOLOCATE_COORDSVIAMETHOD)"
  iscoords "$COORDS" && echo "$MEPO_GEOLOCATE_COORDSVIAMETHOD $COORDS" && return 0

  # Otherwise fallback to use geoclue otherwise
  COORDS="$(coordsviageoclue)"
  iscoords "$COORDS" && echo "coordsviageoclue $COORDS" && return 0

  # If geoclue unavailable use MLS
  COORDS="$(coordsviamls)"
  iscoords "$COORDS" && echo "coordsviamls $COORDS" && return 0

  # If geoclue and MLS unavailable use gpsd
  COORDS="$(coordsviagpsd)"
  iscoords "$COORDS" && echo "coordsviagpsd $COORDS" && return 0

  return 1
}

droppin() {
  SOURCEANDCOORDS="$(getcoords)"
  [ $? = 1 ] && return
  SOURCE="$(echo "$SOURCEANDCOORDS" | cut -d ' ' -f1)"
  COORDS="$(echo "$SOURCEANDCOORDS" | cut -d ' ' -f2-3)"
  LAT="$(echo "$COORDS" | cut -d " " -f1)"
  LON="$(echo "$COORDS" | cut -d " " -f2)"

  echo '[
    {
      "cmd": "pin_add",
      "args": {
        "group": 6,
        "lat": '$LAT',
        "lon": '$LON',
        "handle": "user_location"
      }
    },
    {
      "cmd": "pin_meta",
      "args": {
        "group": 6,
        "handle": "user_location",
        "key": "source",
        "value": "'$SOURCE'"
      }
    },
    {
      "cmd": "pin_meta",
      "args": {
        "group": 6,
        "handle": "user_location",
        "key": "updated_at",
        "value": "'$(date)'"
      }
    }
  ]'
}

droppinactivateandcenter() {
  BASEJSON="$(droppin)"
  ACTIVATEANDCENTERJSON='[
    {"cmd": "pin_activate", "args": {"group": 6, "handle": "user_location"}},
    {"cmd": "center_on_pin", "args": {}}
  ]'
  echo '[ '"$BASEJSON"', '"$ACTIVATEANDCENTERJSON"' ]' | jq flatten
}

main() {
  if [ "$MEPO_USERPIN_ENABLED" = 1 ]; then
    droppinactivateandcenter
  fi
}

if [ -n "$1" ]; then "$@"; else main "$@"; fi
