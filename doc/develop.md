# **Development**

While Mepo is still under active development, a great deal of core
functionality is already built out and the application as a whole
is usable on the Linux desktop and is being tested in parallel on the
Pinephone as well. To run locally you should install Zig 0.8 locally along
with SDL2 SDL2_ttf, SDL2_image, libcurl. Then, to build & run locally run:

- `export PATH="$PATH:$(realpath $(pwd))/scripts"`
- `zig build run`

## Setup on Alpine Linux

There is a work in progress package for Alpine Linux:

https://gitlab.alpinelinux.org/alpine/aports/-/merge_requests/22055/diffs

However, this is not the recommended method to install Zig because Zig 
0.8 is not available in the Alpine repos.
You can download the binary release of Zig 0.8 from the official website:

https://ziglang.org/download/

Finally, install the build dependancies via apk:

```sh
sudo apk add curl-dev sdl2-dev sdl2_image-dev sdl2_ttf-dev
```

After adding zig to your path, run `zig build run`
