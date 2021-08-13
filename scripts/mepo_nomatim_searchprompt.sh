#!/usr/bin/env sh
[ -z "$MEPO_MENU" ] && MEPO_MENU="dmenu -l 10 -w $(xdotool getactivewindow) -p"

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
    $MEPO_MENU "Search for Location" |
    xargs -0 echo "https://nominatim.openstreetmap.org/search?format=json&q=" 
)" |
  jq '.[] | "\(.display_name) \(.lat) \(.lon)" ' |
  $MEPO_MENU "Pick result" |
  grep -oE '(\-|\d|\.)+' |
  tail -n2 |
  tr "\n" " " |
  xargs -I COORDS echo  center_on_coords COORDS ;
