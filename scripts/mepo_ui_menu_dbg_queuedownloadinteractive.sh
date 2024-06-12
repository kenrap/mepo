#!/usr/bin/env sh
DISPLAYNAME=" Download: bounding-box custom zoom levels (interactive)"
HOTKEY=q
DOC='
  Queues the current bounding box / viewport of the map to be downloaded
  in the background. Interactive, in that user is prompted for the
  minimum and maximum zoom-level to be downloaded.
'
BOUND_LOWER=1
BOUND_UPPER=19

main() {
  ZOOM_MIN="$(
    seq $BOUND_LOWER $BOUND_UPPER |
    PROMPT="Download Zoom Min:" mepo_ui_helper_menu.sh 
  )"

  if ! { [ -n "$ZOOM_MIN" ] && [ "$ZOOM_MIN" -gt -1 ] && [ "$ZOOM_MIN" -lt 20 ]; }; then
    echo "Invalid minimum zoom level" >&2
    exit 1
  fi

  ZOOM_MAX="$(
    seq $BOUND_LOWER $BOUND_UPPER |
    PROMPT="Download Zoom Max:" mepo_ui_helper_menu.sh
  )"

  if ! { [ -n "$ZOOM_MAX" ] && [ "$ZOOM_MAX" -gt -1 ] && [ "$ZOOM_MAX" -lt 20 ]; }; then
    echo "Invalid maximum zoom level" >&2
    exit 1
  fi

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
