#!/usr/bin/env sh

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

  echo "move_relative $PANX $PANY";
}

if [ -n "$1" ]; then "$@"; else main; fi

