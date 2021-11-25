#!/usr/bin/env sh
cd "$(realpath $(dirname "$0"))"/..
USER=m
CONN=$USER@pine64-pinephone
rsync -v -a --exclude 'zig-out' --exclude 'zig-cache' . $CONN:/home/$USER/mepo
