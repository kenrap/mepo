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
  curl -Ss "$MEPO_ENDPOINT_OVERPASS" --data-raw "data=
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

  PINSETUPCOMMANDS='
    {"cmd": "prefset_n", "args": { "pref": "pingroup_0_ordered", "value": 0}},
    {"cmd": "pin_groupactivate", "args": {"group": 0}},
    {"cmd": "pin_purge", "args": {}}
  '

  PINADDCOMMANDS="$(
    echo "$JSON_RESULTS" | jq '
      .elements |
      map(
        select(.lat != null and .lon != null) |
        (
          if .tags.name then
            .tags.name
          else
            "'${UNTITLED_LABEL}'"
          end + " (" + (.id|tostring) + ")"
        ) as $handle |

        # Pin add
        {
          "cmd": "pin_add",
          "args": { "handle": $handle, "lat": .lat, "lon":.lon }
        } as $pin_add | 

        # Pin metadata
        [
          if .tags != null then
            .tags | with_entries(
              .value={
                "cmd": "pin_meta", "args": { "handle": $handle, "key": .key, "value": .value }
              }
            ) | map(.)
           else
             null
           end
         ] as $pin_meta  | 
         
         [ $pin_add , $pin_meta ]
      ) | flatten | del(..|nulls)
    '
  )"

  echo "[$PINSETUPCOMMANDS, $PINADDCOMMANDS]" | jq flatten
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
  mapoverpassjsontopins "$JSON_RESULTS" "$(echo "$SCOPE" | cut -d: -f1 | tr -d '[]')"
}

if [ -n "$1" ]; then "$@"; else main; fi
