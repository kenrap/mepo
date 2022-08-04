#!/usr/bin/env sh
DISPLAYNAME=" Location Pin: Center on user location"
HOTKEY=x

coordsviamls() {
  MLSKEY=9a418f3c-364a-418a-85e8-1bde733f0c88
  MLSRESULT="$(
    # TODO: MLS supports POST buffer with network names -- scrape from nmcli
    curl "https://location.services.mozilla.com/v1/geolocate?key=$MLSKEY"
  )"
  LAT="$(echo "$MLSRESULT" | jq '.location.lat')"
  LON="$(echo "$MLSRESULT" | jq '.location.lng')"
  echo "$LAT $LON"
}

coordsviageoclue() {
  supportsgeoclue || return 1

  /usr/libexec/geoclue-2.0/demos/agent > /dev/null &
  AGENTPID=$!
  LATLON="$(
          ( /usr/libexec/geoclue-2.0/demos/where-am-i -t 10 & ) |
          grep -E "Latitude|Longitude:" -m2 |
          cut -d: -f2 |
          tr -d "° " |
          tr "\n" " "
  )"
  kill -9 $AGENTPID
  pkill -9 -f where-am-i
  echo "$LATLON"
}

supportsgeoclue() {
  stat /usr/libexec/geoclue-2.0/demos/agent > /dev/null &&
  stat /usr/libexec/geoclue-2.0/demos/where-am-i > /dev/null
}

coordsviagpsd() {
  # On pmOS: sudo /etc/gpsd/device-hook "" ACTIVATE
  gpspipe -w -n 10 | grep -m 1 TPV | jq '.lat, .lon' | tr '\n' ' '
}

iscoords() {
  echo "$1" | grep -qE '[0-9.\-]+ [0-9.\-]+'
}

getcoords() {
  # Try to get coords from GPSD first
  COORDS="$(coordsviagpsd)"
  iscoords "$COORDS" && echo "gpsd $COORDS" && return 0

  # If gpsd fails use geoclue
  COORDS="$(coordsviageoclue)"
  iscoords "$COORDS" && echo "geoclue $COORDS" && return 0

  # If geoclue fails use mls
  COORDS="$(coordsviamls)"
  iscoords "$COORDS" && echo "mls $COORDS" && return 0

  return 1
}

droppin() {
  SOURCEANDCOORDS="$(getcoords)"
  [ $? == 1 ] && return
  SOURCE="$(echo "$SOURCEANDCOORDS" | cut -d ' ' -f1)"
  COORDS="$(echo "$SOURCEANDCOORDS" | cut -d ' ' -f2-3)"
  LAT="$(echo $SOURCE | cut -d " " -f1)"
  LON="$(echo $SOURCE | cut -d " " -f2)"

  echo "pin_add 7 0 $COORDS user_location;"
  echo "pin_meta 7 user_location lat $LAT;"
  echo "pin_meta 7 user_location lat $LON;"
  echo "pin_meta 7 user_location source $SOURCE;"
  echo "pin_meta 7 user_location updated_at [$(date)];"
}

droppinactivateandcenter() {
  droppin
  echo "pin_activate 7 user_location;"
  echo "center_on_pin;"
}

main() {
  droppinactivateandcenter
}

if [ -n "$1" ]; then "$@"; else main "$@"; fi
