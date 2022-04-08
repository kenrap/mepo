#!/usr/bin/env sh
DISPLAYNAME=" POI Search: via Overpass"
HOTKEY=b

OPTIONS='
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
    echo -e "Cancel\n$OPTIONS" |
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

  SCOPE="$(echo $SCOPE | cut -d ' ' -f2- | tr '\n' ' ')"
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
    pin_groupprefset_n 0 ordered 0;
    pin_groupprefset_n 0 active 1;
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
