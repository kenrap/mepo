#!/usr/bin/env sh
DISPLAYNAME=" Download: current bounding-box (non-interactive)"
BOUND_LOWER=1
BOUND_UPPER=19

main() {
  ZOOM_MIN=$MEPO_ZOOM
  ZOOM_MAX="$(echo -e "19\n$MEPO_ZOOM" | sort -rn | head -n1)"

  echo "
    cache_dlbbox
      $MEPO_BR_LAT
      $MEPO_TL_LON
      $MEPO_TL_LAT
      $MEPO_BR_LON
      $ZOOM_MIN
      $ZOOM_MAX 
    ;

    prefset download_bar 1;
  "
}

if [ -n "$1" ]; then "$@"; else main; fi
