#!/usr/bin/env sh

WIDTH_OR_HEIGHT="$1"
MULT_FACTOR="$2"
PANX=0
PANY=0

if [ "$WIDTH_OR_HEIGHT" = h ]; then
  PANY="$(echo "$MEPO_WIN_H * $MULT_FACTOR" | bc)"
fi

if [ "$WIDTH_OR_HEIGHT" = w ]; then
  PANX="$(echo "$MEPO_WIN_W * $MULT_FACTOR" | bc)"
fi

echo "move_relative $PANX $PANY";
