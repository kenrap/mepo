#!/usr/bin/env sh
DISPLAYNAME=" POI Search: via Nominatim"
HOTKEY=G
DOC='
  Searches for points of intrest via the publically accessible Nominatim
  API based on the current viewport.  Presents menuing to prompt for input
  overpass query. Drops pins on the map for the resulting found points
  of intrest in pin group 0; purging any previous pins in in group 0.
'
[ -z "$MEPO_ENDPOINT_NOMINATIM_SEARCH" ] && MEPO_ENDPOINT_NOMINATIM_SEARCH="https://nominatim.openstreetmap.org/search"
[ -z "$MEPO_ENDPOINT_OSM_WIKI_SPECIALPHRASES" ] && MEPO_ENDPOINT_OSM_WIKI_SPECIALPHRASES='https://wiki.openstreetmap.org/wiki/Special:Export/Nominatim/Special_Phrases/EN'

nominatimspecialphrasesfromwiki() {
  curl "$MEPO_ENDPOINT_OSM_WIKI_SPECIALPHRASES" |
    grep '^| ' |
    grep -v '| -' |
    sed -E 's/\|\|.+$//g' |
    sed -E 's/^\| //g' |
    sort
}

main() {
  QUERY="$(
      printf %b "Enter specific POI name" |
      TEXTINPUT=1 PROMPT="Nominatim Search" mepo_ui_helper_menu.sh |
      sed 's/ /%20/g'
  )"
  [ "$QUERY" = "Cancel" ] && exit
  if echo "$QUERY" | grep -qv . ; then
    echo "Invalid search query for nominatim: $QUERY" >&2
    exit 1
  fi

  VIEWBOX="$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON,$MEPO_BR_LAT"
  JSONRESULTS="$(
    curl "${MEPO_ENDPOINT_NOMINATIM_SEARCH}?format=json&q=$QUERY&viewbox=$VIEWBOX&bounded=1&limit=50&extratags=1"
  )"

  echo "
    prefset_n pingroup_0_ordered 0;
    pin_groupactivate 0;
    pin_purge;
  "

  # Add pin
  echo "$JSONRESULTS" |
    jq '
       map(
         .osm_id as $osmid |
         with_entries(
           if .key=="display_name" then
             .value = (.value | split(",")[0]) else
             .value = .value
           end
         ) | 
         "pin_add -1 0 \(.lat) \(.lon) [\($osmid)]; pin_meta -1 [\($osmid)] name [\(.display_name)];"
       )  | .[]
    ' |
    tr -d '"'

  # Add pin metadata
  echo "$JSONRESULTS" | jq '
    [
      map(
      .osm_id as $osmid | 
      with_entries(
        if .key=="display_name" then 
          .value = (.value | split(",")[0]) else 
          .value = .value 
        end
      ) |
      .display_name as $displayname |
      .extratags | with_entries(.value="pin_meta -1 [\($osmid)] [\(.key)] [\(.value)];") | map(.)
    ) | .[] ]  | flatten(3) | .[]
  ' |
  tr -d '",'

}

if [ -n "$1" ]; then "$@"; else main; fi
