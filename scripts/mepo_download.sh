#!/usr/bin/env sh
DOWNLOAD_REQUEST="40.74946,-74.04673,40.818358,-73.88211,3,19"

cd "$(realpath $(dirname "$0"))"/..
zig build && ./zig-out/bin/mepo -d${DOWNLOAD_REQUEST}
