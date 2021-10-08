#!/usr/bin/env sh
ZOOM_MIN="$(
  seq 1 16 |
  mepo_helper_menu.sh "Download Zoom Min:"
)"

ZOOM_MAX="$(
  seq 1 16 |
  mepo_helper_menu.sh "Download Zoom Max:"
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
