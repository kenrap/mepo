#!/usr/bin/env sh

curl "$(
  echo "Location:" |
    dmenu -w $(xdotool getactivewindow) -p "Place" |
    xargs -0 echo "https://nominatim.openstreetmap.org/search?format=json&q=" 
)" |
  jq '.[] | "\(.display_name) \(.lat) \(.lon)" ' |
  dmenu -l 10 -w $(xdotool getactivewindow) -p "Pick result" |
  grep -oE '(\-|\d|\.)+' |
  tail -n2 |
  tr "\n" " " |
  xargs -I COORDS echo  center_on_coords COORDS ;
