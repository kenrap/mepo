#!/usr/bin/env sh
DISPLAYNAME=" User Location Pin: Toggle autoupdate"
HOTKEY=x

coordsviamls() {
  MLSRESULT="$(
    # TODO: MLS supports POST buffer with network names -- scrape from nmcli
    curl 'https://location.services.mozilla.com/v1/geolocate?key=geoclue'
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
  kill $AGENTPID
  pkill -f where-am-i
  echo "$LATLON"
}

coordsviagpsd() {
  echo # TODO
}

main() {
  SOURCE=geoclue

  if [ "$SOURCE" = mls ]; then
    COORDS="$(coordsviamls)"
  elif [ "$SOURCE" = geoclue ]; then
    COORDS="$(coordsviageoclue)"
  elif [ "$SOURCE" = gpsd ]; then
    COORDS="$(coordsviagpsd)"
  else
    COORDS=""
  fi

  echo "pin_delete 7 user_location;"
  echo "pin_add 7 0 $COORDS user_location;"
  echo "pin_meta 7 user_location source $SOURCE;"
  echo "pin_activate 7 user_location;"
  echo "center_on_pin;"
}

if [ -n "$1" ]; then "$@"; else main; fi
