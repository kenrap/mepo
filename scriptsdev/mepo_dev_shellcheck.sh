#!/usr/bin/env sh
git ls-files | 
  grep -E '.sh$' | 
  xargs shellcheck -e SC2034,SC2002

# SC2034: Unused var For HOTKEY vars
# SC2002: (U?)UOC usually improves readability