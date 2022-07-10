#!/usr/bin/env sh
DISPLAYNAME=" User Location Pin: Toggle autoupdate"
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

coordsviagpsd() {
  echo # TODO
}

supportsgeoclue() {
  stat /usr/libexec/geoclue-2.0/demos/agent > /dev/null &&
  stat /usr/libexec/geoclue-2.0/demos/where-am-i > /dev/null
}

supportsgpsd() {
  return 1 # TODO
}

main() {
  SOURCE=""
  COORDS=""

  # Pull coords from gpsd if available, if not use geoclue
  if supportsgpsd; then
    SOURCE=gpsd
    COORDS="$(coordsviagps)"
  elif supportsgeoclue; then
    SOURCE=geoclue
    COORDS="$(coordsviageoclue)"
  fi

  # E.g. fall back to MLS if coordinate via geoclue or gpsd fails
  if echo "$COORDS" | grep -vq .; then
    SOURCE=mls
    COORDS="$(coordsviamls)"
  fi

  echo "pin_delete 7 user_location;"
  echo "pin_add 7 0 $COORDS user_location;"
  echo "pin_meta 7 user_location source $SOURCE;"
  echo "pin_activate 7 user_location;"
  echo "center_on_pin;"
  exit 0
}

if [ -n "$1" ]; then "$@"; else main; fi
