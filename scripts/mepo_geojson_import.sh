#!/usr/bin/env sh
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

ORIGINLAT="$(echo "$PINADDS" | jq '.[0].args.lat')"
ORIGINLON="$(echo "$PINADDS" | jq '.[0].args.lon')"

PRECMDS='[
    {"cmd": "prefset_n", "args": {"pref": "pingroup_7_ordered", "value": 1}},
    {"cmd": "pin_groupactivate", "args": {"group": 7}},
    {"cmd": "pin_purge", "args": {}},
    {"cmd": "prefset_n", "args": {"pref": "lat", "value": '$ORIGINLAT'}},
    {"cmd": "prefset_n", "args": {"pref": "lon", "value": '$ORIGINLON'}}
]'

echo "[$PRECMDS, $PINADDS]" | jq  '[.[][]]'
