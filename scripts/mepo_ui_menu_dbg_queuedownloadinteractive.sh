#!/usr/bin/env sh
DISPLAYNAME=" Download: custom region (interactive)"
HOTKEY=q
BOUND_LOWER=1
BOUND_UPPER=19

main() {
  ZOOM_MIN="$(
    seq $BOUND_LOWER $BOUND_UPPER |
    PROMPT="Download Zoom Min:" mepo_ui_helper_menu.sh 
  )"

  ZOOM_MAX="$(
    seq $BOUND_LOWER $BOUND_UPPER |
    PROMPT="Download Zoom Max:" mepo_ui_helper_menu.sh 
  )"

  if ! ( [ ! -z "$ZOOM_MIN" ] && [ "$ZOOM_MIN" -gt -1 ] && [ "$ZOOM_MIN" -lt 20 ]); then
    echo "Invalid minimum zoom level" >&2
    exit 1
  fi

  if ! ( [ ! -z "$ZOOM_MAX" ] && [ "$ZOOM_MAX" -gt -1 ] && [ "$ZOOM_MAX" -lt 20 ]); then
    echo "Invalid maximum zoom level" >&2
    exit 1
  fi

  TARGET="$(
    printf %b "bbox\n1km\n2km\n3km\n4km\n10km\n100km" |
    PROMPT="Target (bbox or #km):" mepo_ui_helper_menu.sh 
  )"

  if [ "$TARGET" = bbox ]; then
    # Bbox based downloading
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
  else
    # Radius-based downloading
    echo "
      cache_dlradius
        $MEPO_CENTER_LAT
        $MEPO_CENTER_LON
        $ZOOM_MIN
        $ZOOM_MAX 
        $(echo "$TARGET" | tr -dc '[0-9.]')
      ;
      prefset_n download_bar 1;
    "
  fi
}

if [ -n "$1" ]; then "$@"; else main; fi
