#!/usr/bin/env sh
[ -z "$MEPO_MENU" ] && MEPO_MENU="dmenu -l 10 -w $(xdotool getactivewindow) -p"

ZOOM_MIN="$(
  seq 1 16 |
  $MEPO_MENU "Download Zoom Min:"
)"

ZOOM_MAX="$(
  seq 1 16 |
  $MEPO_MENU "Download Zoom Max:"
)"

echo "
  download_bbox
    $MEPO_BR_LAT
    $MEPO_TL_LON
    $MEPO_TL_LAT
    $MEPO_BR_LON
    $ZOOM_MIN
    $ZOOM_MAX 
  ;
"
