#!/usr/bin/env sh
DISPLAYNAME="∴ POI Search: via Nominatim"
HOTKEY=G
DOC='
  Searches for points of interest via the publicly accessible Nominatim
  API based on the current viewport.  Presents menuing to prompt for input
  overpass query. Drops pins on the map for the resulting found points
  of interest in pin group 0; purging any previous pins in in group 0.
'
[ -z "$MEPO_ENDPOINT_NOMINATIM_SEARCH" ] && MEPO_ENDPOINT_NOMINATIM_SEARCH="https://nominatim.openstreetmap.org/search"
[ -z "$MEPO_ENDPOINT_OSM_WIKI_SPECIALPHRASES" ] && MEPO_ENDPOINT_OSM_WIKI_SPECIALPHRASES='https://wiki.openstreetmap.org/wiki/Special:Export/Nominatim/Special_Phrases/EN'

nominatimspecialphrasesfromwiki() {
  curl -Ss "$MEPO_ENDPOINT_OSM_WIKI_SPECIALPHRASES" |
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
    curl -Ss "${MEPO_ENDPOINT_NOMINATIM_SEARCH}?format=json&q=$QUERY&viewbox=$VIEWBOX&bounded=1&limit=50&extratags=1"
  )"

  PINSETUPCOMMANDS='
    [
      {"cmd": "prefset_n", "args": { "pref": "pingroup_0_ordered", "value": 0}},
      {"cmd": "pin_groupactivate", "args": {"group": 0}},
      {"cmd": "pin_purge", "args": {}}
    ]
  '
  PINADDCOMMANDS="$(
    echo "$JSONRESULTS" | jq '
         map(
           .osm_id as $osmid |
           with_entries(
             if .key=="display_name" then
               .value = (.value | split(",")[0]) else
               .value = .value
             end
           ) | 

           # pin_add
           [
            {
               "cmd": "pin_add", 
               "args": {
                 "handle": $osmid|tostring,
                 "lat": .lat|tonumber,
                 "lon": .lon|tonumber
               }
            }
          ] as $pin_add |

          # pin_meta for the display_name
          {
             "cmd": "pin_meta", 
             "args": {
               "handle": $osmid|tostring,
               "key": "name",
               "value": .display_name
             }
          } as $pin_meta_displayname |

          # pin_meta for properties
          [
            if .extratags != null then
              .extratags | with_entries(
                .value={"cmd": "pin_meta", "args": {"handle": $osmid|tostring, "key": .key, "value": .value}}
              ) | map(.)
            else
              null
            end
          ] as $pin_meta_tags |

          [ $pin_add, $pin_meta_displayname, $pin_meta_tags ]
         ) | flatten | del(..|nulls)
      '
  )"

  echo "[$PINSETUPCOMMANDS, $PINADDCOMMANDS]" | jq flatten
}

if [ -n "$1" ]; then "$@"; else main; fi
