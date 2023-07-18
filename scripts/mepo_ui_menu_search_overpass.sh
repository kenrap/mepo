#!/usr/bin/env sh
DISPLAYNAME="∴ POI Search: via Overpass"
HOTKEY=b
DOC='
  Searches for points of interest via the publicly accessible Overpass
  API based on the current viewport.  Presents menuing to prompt for input
  overpass query. Drops pins on the map for the resulting found points
  of interest in pin group 0; purging any previous pins in in group 0.
'
[ -z "$MEPO_ENDPOINT_OVERPASS" ] && MEPO_ENDPOINT_OVERPASS="https://lz4.overpass-api.de/api/interpreter"

curloverpass() {
  SCOPE="$(echo "$SCOPE" | cut -d: -f1 | tr '\n' ' ')"
  BBOX="$MEPO_BR_LAT,$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON"
  curl "$MEPO_ENDPOINT_OVERPASS" --data-raw "data=
      [out:json][timeout:25];
      (
        node${SCOPE}(${BBOX});
        way${SCOPE}(${BBOX});
        relation${SCOPE}(${BBOX});
      );
      out+body 100;
      >;
      out+skel+qt;
  "
}

mapoverpassjsontopins() {
  JSON_RESULTS="$1"
  UNTITLED_LABEL="$2"

  # E.g. label set to 'tags.name (id)'
  # when tags.name unset; label will appear just as '$UNTITLED_LABEL (id)'
  PINHANDLEJQ='if .tags.name then .tags.name else "'${UNTITLED_LABEL}'" end + " (" + (.id|tostring) + ")"'

  # Add pin
  echo "$JSON_RESULTS" | jq '
    .elements | .[] | select(.lat != null and .lon != null) |
    "pin_add -1 0 \(.lat) \(.lon) [\('"$PINHANDLEJQ"')];"
  ' | tr -d ',"'


  # Add pin metadata
  echo "$JSON_RESULTS" | jq '
    .elements | .[] | select(.lat != null and .lon != null) |
    ('"$PINHANDLEJQ"') as $handle |
    [.tags] |
    map(
      to_entries |
      map("pin_meta -1 [" + $handle + "] [" + .key + "] [" + .value + "];")
    ) |
    flatten(3) |
    .[]
  ' | tr -d ',"'
}

main() {
  OPTIONS="$(mepo_generated_osmtags.sh)"
  SCOPE="$(
    printf %b "Cancel\n$OPTIONS" |
      sed 's/^ *//' |
      sed 's/ *$//' |
      grep . | 
      PROMPT="Overpass Search" mepo_ui_helper_menu.sh
  )"
  [ "$SCOPE" = "Cancel" ] && exit
  if echo "$SCOPE" | grep -qv . ; then
    echo "Invalid search query for overpass: $SCOPE" >&2
    exit 1
  fi

  JSON_RESULTS="$(curloverpass "$SCOPE")"
  echo "
    prefset_n pingroup_0_ordered 0;
    pin_groupactivate 0;
    pin_purge;
  "
  mapoverpassjsontopins "$JSON_RESULTS" "$(echo "$SCOPE" | cut -d: -f1 | tr -d '[]')"
}

if [ -n "$1" ]; then "$@"; else main; fi
