#!/usr/bin/env sh

echo foo | dmenu

BBOX="40.74595644996025,-74.04390335083008,40.811730481593585,-73.90829086303711"

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