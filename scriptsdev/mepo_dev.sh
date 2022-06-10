#!/usr/bin/env sh
set -e
cd "$(realpath "$(dirname "$0")")"/.. || exit 1
NEWPATH="$PATH:$(realpath "$(pwd)")/scripts"
export PATH="$NEWPATH"
zig build

if [ "$GDB" = 1 ]; then
  gdb ./zig-out/bin/mepo "$@"
else
  ./zig-out/bin/mepo "$@"
fi
