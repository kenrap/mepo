#!/usr/bin/env sh
git ls-files | grep '\.zig$' | xargs zig fmt
