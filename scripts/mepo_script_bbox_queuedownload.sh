#!/usr/bin/env sh

BOUND_LOWER=1
BOUND_UPPER=19

ZOOM_MIN="$(
  seq $BOUND_LOWER $BOUND_UPPER |
  mepo_helper_menu.sh "Download Zoom Min:"
)"

ZOOM_MAX="$(
  seq $BOUND_LOWER $BOUND_UPPER |
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

  prefset download_bar 1;
"
