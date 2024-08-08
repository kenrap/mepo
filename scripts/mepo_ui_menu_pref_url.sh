#!/usr/bin/env sh
DISPLAYNAME="⚙ Update: Tilesource"
HOTKEY=v
DOC='
  Updates the tilesource for the map to pull from. Note %1$d, %2$d, and %3$d
  are used to indicate X, Y, and Z variables respectively. Presents menuing
  with presets for OSM Maps, Stamen, OpenCycleMap etc.
'

main() {
  # Note X, Y, Z provided as %1$d, %2$d, %3$d respectively
  # shellcheck disable=SC2016
  SOURCES='
    OSM Maps: https://tile.openstreetmap.org/%3$d/%1$d/%2$d.png
    OpenTopoMap C: https://c.tile.opentopomap.org/%3$d/%1$d/%2$d.png
    OpenTopoMap B: https://b.tile.opentopomap.org/%3$d/%1$d/%2$d.png
    OpenTopoMap A: https://a.tile.opentopomap.org/%3$d/%1$d/%2$d.png
    Railway: http://a.tiles.openrailwaymap.org/signals/%3$d/%1$d/%2$d.png
    Railway: http://b.tiles.openrailwaymap.org/signals/%3$d/%1$d/%2$d.png
    Railway: http://c.tiles.openrailwaymap.org/signals/%3$d/%1$d/%2$d.png
    OpenPT: http://www.openptmap.org/tiles/${z}/${x}/${y}.png 
    Stamen: http://a.tile.stamen.com/toner/%3$d/%1$d/%2$d.png
    OpenCycleMap: http://tile.thunderforest.com/cycle/%3$d/%1$d/%2$d.png
    Google Maps: http://mts0.google.com/vt/hl=en&src=api&x=%1$d&s=&y=%2$d&z=%3$d
  '

  echo "$SOURCES" | 
    awk '{$1=$1};1' | 
    grep . | 
    PROMPT="Tile Source" mepo_ui_helper_menu.sh |
    cut -d: -f2- |
    tr -d ' ' |
    xargs -IURL echo '
      [{
        "cmd": "prefset_t",
        "args": {
          "pref": "tile_cache_url",
          "value": "'URL'"
        }
      }]
    '
}

if [ -n "$1" ]; then "$@"; else main; fi
