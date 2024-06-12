#!/usr/bin/env sh
# This script maps geojson to mepo's pin_add & pin_meta syntax.
# 
# May be used as:
#   cat geojson_file.json | mepo_geojson_import.sh > ~/.config/mepo/bookmarks.json
#
jq '[
  .[] | 
  select(.geometry.type == "Point").geometry.coordinates | 
  {
    "cmd": "pin_add", 
    "args": {
      "handle": "geojson_\(.[1])_\(.[0])",
      "lat": .[1],
      "lon": .[0]
    }
  }
]'
