#!/usr/bin/env sh

errdie() {
  echo "$1" >&2
  exit 1
}

bbox() {
  DOWNLOAD_REQUEST=$1
  cd "$(realpath $(dirname "$0"))"/..
  zig build && ./zig-out/bin/mepo -d${DOWNLOAD_REQUEST}
}

nominatim() {
  echo "Target download location"
  echo "(can be city like New York City, country like Italy, state like Texas)"
  read -p "Location: " LOCATION
  LOCATION="$(echo "$LOCATION" | sed 's/ /%20/g')"

  OPTIONS="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$LOCATION" |
      jq  '.[] | select(.osm_type == "relation") | "\(.display_name) \(.boundingbox)" ' |
      tr -d '\]\[\\"' |
      sed -E 's/([^ ]+)$/ | \1/g' |
      column -t -s\| |
      nl |
      sed 's/^ *//g'
  )"
  echo "$OPTIONS"
  read -p "Pick number: " NUMBER
  BBOX="$(echo "$OPTIONS" | grep -E "^${NUMBER}" | awk -F' ' '{print $NF}')"
  echo "$BBOX" | grep . || errdie "Invalid option"

  # Nominatim BBOX south lat , north lat, west lon, east lon -> conv to mepo format lat1,lon1,lat2,lon2Q
  BBOX="$(echo "$BBOX" | awk -F, '{print $1, $3, $2, $4 }' | tr " " ",")"

  read -p "Zoom minimum (0-19): " ZOOM_MIN
  read -p "Zoom maximum (0-19): " ZOOM_MAX

  bbox "$BBOX,$ZOOM_MIN,$ZOOM_MAX"
}


test() {
  DOWNLOAD_REQUEST="40.74946,-74.04673,40.818358,-73.88211,3,16"
  bbox "$DOWNLOAD_REQUEST"
}

"$@"
