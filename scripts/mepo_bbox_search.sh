#!/usr/bin/env sh

BBOX="$MEPO_BR_LAT,$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON"
echo "$BBOX" | 
  dmenu -l 10 -p "Bbox POI Search"

JSON_RESULTS="$(
  curl  "https://lz4.overpass-api.de/api/interpreter" --data-raw "data=$(
    echo '
      [out:json][timeout:25];
      (
        node["amenity"="restaurant"]["cuisine"="italian"](BBOX);
        way["amenity"="restaurant"]["cuisine"="italian"](BBOX);
        relation["amenity"="restaurant"]["cuisine"="italian"](BBOX);
      );
      out+body;
      >;
      out+skel+qt;
    ' | sed "s/BBOX/$BBOX/g"
  )"
)"

echo "$JSON_RESULTS" |
  jq '.elements | .[] | "\(.lat) \(.lon) \(.tags.name)" ' |
  tr -d \" |
  grep -vE 'null$' |
  grep -vE '^null' |
  awk -F' ' '{print $1 " " $2 " " $3}' |
  sed 's/[^[:print:]]//g' |
  head -n 20 |
  xargs -ID echo 'pin_add D;'