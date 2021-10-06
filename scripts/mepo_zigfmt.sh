#!/usr/bin/env sh
ag -g 'zig$' | xargs zig fmt
