# Mepo: **Development Guide**

## Overview

While Mepo is still under active development, a great deal of core
functionality is already built out and the application as a whole
is usable on the Linux desktop and is being tested in parallel on the
PinePhone as well. To run locally you should install Zig 0.8.1 locally along
with SDL2, SDL2_ttf, SDL2_image, libcurl. Then, to build & run locally run:

- `export PATH="$PATH:$(realpath $(pwd))/scripts"`
- `zig build run`

## Setup on Alpine Linux

Alpine Linux build dependencies:

```sh
apk add curl-dev sdl2-dev sdl2_image-dev sdl2_ttf-dev sdl2_gfx-dev
```

Alpine Linux runtime dependencies:

```sh
apk add dmenu jq xdotool curl ncurses font-inconsolata-nerd
```

## Code Style

Run all files through `zig fmt`:

```sh
scriptsdev/mepo_dev_zigfmt.sh
```

## Hacking Guide: Concurrency Model

### Interactive mode

While running in interactive mode, there's essentially 1-3 threads used by
Mepo. The underlying data structure that manages thread-safety is the
`QueueHashMap` which is used by the `TileCache`'s LIFO, transfer map, and
texture map and uses mutexes around Zig's `ArrayHashMap`.

The three threads used in interactive mode are:

1. The primary SDL thread (always present)
2. The downloading thread (`TileCache.thread_download`,
   present if `set_network` is true)
3. The `bbox` queueing thread  (`TileCache.thread_queuebbox`,
   present while queueing a `bbox`)

(1) is always present from when you launch the application. (2) may be toggled
on and off given the `set_network` function. And (3) may be toggled on or off
given the `set_queue` function.

If (3) is present, you can assumed (2) is present - e.g. no queueing can take
place if there's no download thread.

The reason (3)'s logic is managed in a separate thread is that given a `bbox`,
we need to convert all coordinates into the queue. This takes time because you
can for example queue the entire globe if desired.

### Noninteractive mode

While running in non-interactive mode (with `-d`), the application runs
as simple single-threaded application. Basically non-interactive mode is
just a hook into the downloading thread (2) mentioned above. Before starting
the downloading thread, the bounding-box is queued (non-concurrently,
in contrast to in interactive mode in which queueing and downloading
happens simultaneously).
