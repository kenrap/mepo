#!/usr/bin/env sh
echo prefset zoom "$(
  seq 1 16 |
  mepo_helper_menu.sh "Zoom"
);"
