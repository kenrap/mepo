#!/usr/bin/env sh

echo prefset zoom "$(
  seq 1 16 |
  $MEPO_MENU "Zoom"
);"
