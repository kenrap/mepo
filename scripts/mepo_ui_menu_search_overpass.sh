#!/usr/bin/env sh
DISPLAYNAME=" POI Search: via Overpass"
HOTKEY=b

OPTIONS='
  Cancel
  Bars:          [amenity=bar]
  Restraunt:     [amenity=restaurant]
  Pizza:         [amenity=restaurant] [cuisine=italian]
  Indian:        [amenity=restaurant] [cuisine=indian]
  Supermarket:   [shop=supermarket]
  Coffeshop:     [amenity=cafe]
  Grocery:       [shop=grocery]
  Bathrooms:     [amenity=toilets]
'

main() {
  SCOPE="$(
    echo "$OPTIONS" |
      sed 's/^ *//' |
      sed 's/ *$//' |
      grep . | 
      PROMPT="Bbox POI Search" mepo_ui_helper_menu.sh |
      cut -d ' ' -f2- |
      tr '\n' ' '
  )"
  [ "$SCOPE" = "Cancel" ] && exit
  if [ -z "$SCOPE" ]; then
    echo "Invalid search query for overpass: $SCOPE" >&2
    exit 1
  fi

  BBOX="$MEPO_BR_LAT,$MEPO_TL_LON,$MEPO_TL_LAT,$MEPO_BR_LON"
  JSON_RESULTS="$(
    curl  "https://lz4.overpass-api.de/api/interpreter" --data-raw "data=$(
      echo '
        [out:json][timeout:25];
        (
          nodeSCOPE(BBOX);
          waySCOPE(BBOX);
          relationSCOPE(BBOX);
        );
        out+body 100;
        >;
        out+skel+qt;
      ' | sed "s/BBOX/$BBOX/g" | sed "s/SCOPE/$SCOPE/g"
    )"
  )"

  echo "
    pin_groupprefset 0 ordered 0;
    pin_groupprefset 0 active 1;
    pin_purge;
  "

  echo "$JSON_RESULTS" | jq '
    .elements |
    .[] |
    select(.lat != null and .lon != null and .tags.name != null) |
    "pin_add -1 0 \(.lat) \(.lon) [\(.tags.name)] [\(.tags.name)];"
  ' | tr -d ',"'

  # Add pin metadata
  echo "$JSON_RESULTS" | jq '
    [.elements | .[] | .tags | select(. != null and .name != null)] | 
    map(
      .name as $handle | 
      to_entries |  
      map("pin_meta -1 [" + $handle + "] [" + .key + "] [" + .value + "];")
    ) | 
    flatten(3) |
    .[]
  ' | tr -d ',"'
}

if [ -n "$1" ]; then "$@"; else main; fi
