#!/usr/bin/env sh
cd "$(realpath "$(dirname "$0")")"/.. || exit 1
NEWPATH="$PATH:$(realpath "$(pwd)")/scripts"
export PATH="$NEWPATH"
zig build && ./zig-out/bin/mepo "$@"
