# Mepo: **User Guide**

**Table of contents:**
- [Basic Interface Overview]()
- [POI Searches]()
- [Routing](#routing)
- [Repositioning the map]()
- [Autoloading preferences]()
- [Offline Usage]()
- [Mepolang]()

## Basic Interface Overview

Interface overview here. Link to [hotkeys](../src/config.zig#L18).

## POI Searches

POI searches placeholder.

## Routing

Routing placeholder.

## Autoloading preferences

Autoloading preference placeholder.

## Offline Usage

## Using the `tile_cache_network` parameter

If you have already used Mepo to download tiles, either interactively or
through the `mepo_dl.sh` script as described above; you may use Mepo entirely
offline by setting the preference `tile_cache_network` to `0`.

```sh
echo "prefset tile_cache_network 0;" | mepo -i
```

You'll see this noted noted in the download bar as `Offline`.

This mode is helpful if you have bandwidth limitations (e.g. for your data plan
or similar) and want to make sure Mepo does not make **any** network requests.


### Downloading tiles

It's a common use case to need to download an entire block / bounding box
of tiles while online before going offline. For example, say if you want
to use your phone with Mepo but are not sure you'll not have internet
access at your destination.

To facilitate downloading of tiles, Mepo features a non-interactive CLI
accessible through using the `-d` flag. This flag should be suffixed with
a list of 6 comma separate parameters (no whitespaces) in the form of
`lat_a,lon_a,lat_b,lon_b,zoom_min,zoom_max`. Zoom min and max can range
from 0-16. 

For example, to download a bounding box:

```sh
mepo -d40.74946,-74.04673,40.818358,-73.88211,3,16
```

This may be a bit more involved then you would like to get, so as an
alternative you can use the provided `mepo_dl.sh` script which provides
a prompt-driven dialog which queries [Nominatim](https://nominatim.org)
to determine the bounding box to download and then feeds this into `mepo -d`.

Run this script as:

```sh
mepo_dl.sh
```

See below section for information about offline usage.


## Mepolang

Mepolang is Mepo's command language API for IPC that can be sent to its
process via STDIN continually. Through this mechanism you can control
Mepo: using an external script, by simply piping in a configuration
on boot, or by using a FIFO (eventually). Upon the 1.0 release it is
planned that there will be two commands included to run Mepo: `mepo`
and `mepo_run.sh` wherein `mepo_run.sh` will just be a script that runs
`cat default_config | mepo`.

Many of Mepo's commands play nice together. A good place to look to
understand Mepolang's utilization is the [default config](../src/config.zig). For
example `bind_key` actually also takes Mepolang text to run as an
argument. Similarly the result of `shellpipe`, runs Mepolang text given
the STDOUT result of a (user) [shellscript](../scripts).

### Mepolang syntax rules

- Each statement is made up of multiple tokens.
- Each Mepolang command should be terminated by a semicolon.
- The first token in a statement is always the command name.
- Tokens should be separated by whitespace.
- Each token is either:
  - Text
    - Just plain text, by default assumed to be a single word.
    - If you want to use a space within an argument use `[ square brackets ]` to create a multiword token.
    - If you want to have a text token that looks like a number, use square brackets like `[-3]`
  - Number
    - A floating point number, either decimal (e.g. `3.77`) or whole (e.g. `3`).
    - Can be negative like `-22.22` or positive like `22.22`

### Mepolang syntax example

```sh
commandname textarg [multi word arg] 2;
commandname2 arg 8.373 anothertextarg;
```

### Using a custom Mepolang configuration

Eventually Mepo will be able to be continually fed Mepolang input as
STDIN. This is not the case currently - and you can only feed in STDIN
once as configuration upon boot. This can be done to override the default
configuration. Use the `-i` option to indicate Mepo should look for STDIN
configuration upon boot.

For example, to set the default zoom-level upon boot to 10:

```sh
echo "prefset zoom 10;" | mepo -i
```
