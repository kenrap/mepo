#!/usr/bin/env sh
DOC='
  Given param DIM uses MEPO_WIN_W/H to pan screenwise vertically or
  horizontally. Used to mimic C-f/C-b vim-like behavior.
'

main() {
  # TODO: -z check DIM/MULT
  PANX=0
  PANY=0

  if [ "$DIM" = h ]; then
    PANY="$(echo "$MEPO_WIN_H * $MULT" | bc)"
  fi

  if [ "$DIM" = w ]; then
    PANX="$(echo "$MEPO_WIN_W * $MULT" | bc)"
  fi

  echo '
    [{
      "cmd": "move_relative",
      "args": {
        "rel_x": '$PANX',
        "rel_y": '$PANY'
      }
    }]
  ';
}

if [ -n "$1" ]; then "$@"; else main; fi

