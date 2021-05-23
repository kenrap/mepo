#!/usr/bin/env sh

echo prefset_n zoom "$(
  seq 1 16 |
  dmenu -l 10 -w $(xdotool getactivewindow) -p "Zoom"
)"
