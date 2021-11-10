# Mepo: **Development Guide**

## Overview

While Mepo is still under active development, a great deal of core
functionality is already built out and the application as a whole
is usable on the Linux desktop and is being tested in parallel on the
Pinephone as well. To run locally you should install Zig 0.8.1 locally along
with SDL2 SDL2_ttf, SDL2_image, libcurl. Then, to build & run locally run:

- `export PATH="$PATH:$(realpath $(pwd))/scripts"`
- `zig build run`

## Setup on Alpine Linux

Alpine linux dependencies:

```sh
apk add curl-dev sdl2-dev sdl2_image-dev sdl2_ttf-dev
```

## Code Style

Run all files through zig fmt:

```sh
ag -g zig | xargs zig fmt
```
