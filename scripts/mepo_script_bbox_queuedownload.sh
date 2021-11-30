#!/usr/bin/env sh
BOUND_LOWER=1
BOUND_UPPER=19

noninteractive() {
  ZOOM_MIN=$MEPO_ZOOM
  ZOOM_MAX="$(echo -e "19\n$MEPO_ZOOM" | sort -rn | head -n1)"

  echo "
    cache_bboxdl
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

interactive() {
  ZOOM_MIN="$(
    seq $BOUND_LOWER $BOUND_UPPER |
    mepo_helper_menu.sh "Download Zoom Min:"
  )"

  ZOOM_MAX="$(
    seq $BOUND_LOWER $BOUND_UPPER |
    mepo_helper_menu.sh "Download Zoom Max:"
  )"

  if ! ( [ ! -z "$ZOOM_MIN" ] && [ "$ZOOM_MIN" -gt -1 ] && [ "$ZOOM_MIN" -lt 20 ]); then
    echo "Invalid minimum zoom level" >&2
    exit 1
  fi

  if ! ( [ ! -z "$ZOOM_MAX" ] && [ "$ZOOM_MAX" -gt -1 ] && [ "$ZOOM_MAX" -lt 20 ]); then
    echo "Invalid maximum zoom level" >&2
    exit 1
  fi

  echo "
    cache_bboxdl
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

"$@"
