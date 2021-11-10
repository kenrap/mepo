#!/usr/bin/env sh

errdie() {
  echo "$1" >&2
  exit 1
}

bbox() {
  DOWNLOAD_REQUEST=$1

  if [ -f "$(realpath $(dirname "$0"))/../build.zig" ]; then
    # E.g. dev testing
    cd "$(realpath $(dirname "$0"))"/..
    zig build && ./zig-out/bin/mepo -d${DOWNLOAD_REQUEST} else
    # E.g. installed to system
    mepo -d${DOWNLOAD_REQUEST}
  fi
}

sep() {
  echo "$(tput bold)================================$(tput sgr0)"
}

prompt() {
  NAME="$1"
  read -p "$(tput bold)$NAME$(tput sgr0) " RES
  echo "$RES"
}

nominatim() {
  BBOX=""
  ZOOM_MIN=""
  ZOOM_MAX=""

  echo "$(tput bold)$(basename $0): nominatim$(tput sgr0):"
  sep

  # Location query
  echo "Target download location (city like New York City, country like Italy, state like Texas)"
  LOCATION="$(prompt Location: | sed 's/ /%20/g')"

  OPTIONS="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$LOCATION" |
      jq  '.[] | select(.osm_type == "relation") | "\(.display_name) \(.boundingbox)" ' |
      tr -d '\]\[\\"' |
      sed -E 's/([^ ]+)$/ | \1/g' |
      column -t -s\| |
      nl |
      sed 's/^ *//g'
  )"
  [ -z "$OPTIONS" ] && errdie "Problem fetching from nominatim for request: $LOCATION"

  # Pick location from list
  while [ -z "$BBOX" ]; do
    echo "$OPTIONS"
    NUMBER="$(prompt "Pick number:")"
    BBOX="$(echo "$OPTIONS" | grep -E "^${NUMBER}" | awk -F' ' '{print $NF}')"
    [ -z "$BBOX" ] && echo "Invalid option" && continue
    # Nominatim BBOX south lat , north lat, west lon, east lon -> conv to mepo format lat1,lon1,lat2,lon2Q
    BBOX="$(echo "$BBOX" | awk -F, '{print $1, $3, $2, $4 }' | tr " " ",")"
  done

  while ! ( [ ! -z "$ZOOM_MIN" ] && [ "$ZOOM_MIN" -gt -1 ] && [ "$ZOOM_MIN" -lt 20 ]); do
    ZOOM_MIN="$(prompt "Zoom minimum (0-19):")"
  done

  while ! ( [ ! -z "$ZOOM_MAX" ] && [ "$ZOOM_MAX" -gt -1 ] && [ "$ZOOM_MAX" -lt 20 ]); do
    ZOOM_MAX="$(prompt "Zoom maximum (0-19):")"
  done

  sep
  bbox "$BBOX,$ZOOM_MIN,$ZOOM_MAX"
}


test() {
  DOWNLOAD_REQUEST="40.74946,-74.04673,40.818358,-73.88211,3,16"
  bbox "$DOWNLOAD_REQUEST"
}

[ -z "$1" ] && errdie "Usage: $0 {nominatim,test}" || "$@"
