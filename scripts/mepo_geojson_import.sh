#!/usr/bin/env sh
# This script maps geojson to mepo's pin_add & pin_meta syntax.
# 
# May be used as:
#   cat geojson_file.json | mepo_geojson_import.sh > ~/.config/mepo/bookmarks.json

INPUT="$(cat)"
PINADDS="$(
  echo "$INPUT" | jq '[
    .[] | 
    select(.geometry.type == "Point") | 
    {
      "cmd": "pin_add", 
      "args": {
        "group": 7,
        "handle": (
          if(.properties != null and .properties.name != null) then 
            .properties.name
          else
              "geojson_\(.geometry.coordinates.[1])_\(.geometry.coordinates.[0])"
          end
        ),
        "lat": .geometry.coordinates.[1],
        "lon": .geometry.coordinates.[0]
      }
    }
  ]'
)"

PRECMDS='[
    {"cmd": "prefset_n", "args": {"pref": "pingroup_7_ordered", "value": 1}},
    {"cmd": "pin_groupactivate", "args": {"group": 7}},
    {"cmd": "pin_purge", "args": {}}
]'

echo "[$PRECMDS, $PINADDS]" | jq  '[.[][]]'
