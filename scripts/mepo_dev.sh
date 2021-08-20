#!/usr/bin/env sh
cd "$(realpath $(dirname "$0"))"/..
export PATH="$PATH:$(realpath $(pwd))/scripts"
zig build run
