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
  /usr/libexec/geoclue-2.0/demos/agent &
  AGENTPID=$!
  #/usr/libexec/geoclue-2.0/demos/where-am-i
  kill $AGENTPID
}

coordsviagpsd() {
  echo # TODO
}

main() {
  SOURCE=mls

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
