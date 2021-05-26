#!/usr/bin/env sh

OPTIONS='
  Amsterdam
  Paris
  NYC
  Boston
  India
  Romania
  Iraq
'

curl "$(
  echo "$OPTIONS" |
    awk '{$1=$1};1' | 
    grep . | 
    dmenu -l 10 -w $(xdotool getactivewindow) -p "Search for Location" |
    xargs -0 echo "https://nominatim.openstreetmap.org/search?format=json&q=" 
)" |
  jq '.[] | "\(.display_name) \(.lat) \(.lon)" ' |
  dmenu -l 10 -w $(xdotool getactivewindow) -p "Pick result" |
  grep -oE '(\-|\d|\.)+' |
  tail -n2 |
  tr "\n" " " |
  xargs -I COORDS echo  center_on_coords COORDS ;
