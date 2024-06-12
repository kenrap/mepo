#!/usr/bin/env sh
DISPLAYNAME="  Download: bounding-box all zoom levels (non-interactive)"
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

  echo '[
      {
        "cmd": "cache_dlbbox",
        "args": {
          "a_lat": '$MEPO_BR_LAT',
          "a_lon": '$MEPO_TL_LON',
          "b_lat": '$MEPO_TL_LAT',
          "b_lon": '$MEPO_BR_LON',
          "zoom_min": '$ZOOM_MIN',
          "zoom_max": '$ZOOM_MAX'
        }
      },
      {"cmd": "prefset_n", "args": { "pref": "download_bar", "value": 1 }}
  ]'
}

if [ -n "$1" ]; then "$@"; else main; fi
