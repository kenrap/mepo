#!/usr/bin/env sh
cd "$(realpath $(dirname "$0"))"/..
CONN=user@pine64-pinephone
rsync -v -a --exclude 'zig-out' --exclude 'zig-cache' . $CONN:/home/user/mepo
