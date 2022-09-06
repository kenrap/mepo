#!/usr/bin/env sh
DISPLAYNAME=" Download: current bounding-box (non-interactive)"
HOTKEY=Q
DOC='
  Queues the current bounding box / viewport of the map to be downloaded
  in the background. Non-interactive, in that user is not prompted for
  zoom-level etc. All zoomlevels equal to and higher then the current
  zoom level are downloaded.
'

main() {
  ZOOM_MIN=$MEPO_ZOOM
  ZOOM_MAX="$(printf %b "19\n$MEPO_ZOOM" | sort -rn | head -n1)"

  echo "
    cache_dlbbox
      $MEPO_BR_LAT
      $MEPO_TL_LON
      $MEPO_TL_LAT
      $MEPO_BR_LON
      $ZOOM_MIN
      $ZOOM_MAX 
    ;

    prefset_n download_bar 1;
  "
}

if [ -n "$1" ]; then "$@"; else main; fi
