#!/usr/bin/env sh
jq '[
  .[] | 
  select(.geometry.type == "Point").geometry.coordinates | 
  {
    "cmd": "pin_add", 
    "args": {
      "handle": "geojson_\(.[0])_\(.[1])",
      "lat": .[0],
      "lon": .[1]
    }
  }
]'
