#!/usr/bin/env sh
DISPLAYNAME=" POI Search: via Nominatim"
HOTKEY=G

nominatimspecialphrasesfromwiki() {
  curl 'https://wiki.openstreetmap.org/wiki/Special:Export/Nominatim/Special_Phrases/EN' |
    grep '^| ' |
    grep -v '| -' |
    sed -E 's/\|\|.+$//g' |
    sed -E 's/^\| //g' |
    sort
}

main() {
  QUERY="$(
      echo -e "Cancel\nEnter specific POI name" |
      PROMPT="Nominatim Search" mepo_ui_helper_menu.sh |
      sed 's/ /%20/g'
  )"
  [ "$QUERY" = "Cancel" ] && exit
  if echo "$QUERY" | grep -qv . ; then
    echo "Invalid search query for nominatim: $QUERY" >&2
    exit 1
  fi

  VIEWBOX="$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON,$MEPO_BR_LAT"
  JSONRESULTS="$(
    curl "https://nominatim.openstreetmap.org/search?format=json&q=$QUERY&viewbox=$VIEWBOX&bounded=1&limit=50&extratags=1"
  )"

  echo "
    pin_groupprefset 0 ordered 0;
    pin_groupprefset 0 active 1;
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
         "pin_add -1 0 \(.lat) \(.lon) [\($osmid)] [\(.display_name)];"
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
