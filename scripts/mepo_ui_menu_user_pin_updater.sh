#!/usr/bin/env sh
DISPLAYNAME=" User Location Pin: Toggle autoupdate"
HOTKEY=x

coordsviamls() {
  MLSRESULT="$(
    curl 'https://location.services.mozilla.com/v1/geolocate?key=geoclue'
  )"

  LAT="$(echo "$MLSRESULT" | jq '.location.lat')"
  LON="$(echo "$MLSRESULT" | jq '.location.lng')"

  echo "$LAT $LON"
}

coordsviageoclue() {
  echo # TODO
}

coordsviagpsd() {
  echo # TODO
}

main() {
  COORDS="$(coordsviamls)"
  echo "pin_delete 7 user_location;"
  echo "pin_add 7 0 $COORDS user_location;"
  echo "pin_meta 7 user_location source mls;"
  echo "pin_activate 7 user_location;"
  echo "center_on_pin;"
}

if [ -n "$1" ]; then "$@"; else main; fi
