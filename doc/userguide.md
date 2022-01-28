# Mepo: **User Guide**

> **Disclaimer**: This guide is a work-in-progress and not complete!

## **Table of contents:**
- [Basic Interface Overview](#basic-interface-overview)
- [The Central Menu](#the-central-menu)
- [POI Searches](#poi-searches)
- [Routing](#routing)
- [Repositioning the map](#repositioning-the-map)
- [Autoloading preferences](#autoloading-preferences)
- [Offline Usage](#offline-usage)
- [Mepolang](#mepolang)

## **Basic Interface Overview**

Mepo is a fast, simple, and hackable OSM map viewer for desktop & mobile
Linux devices (like the PinePhone, Librem 5 etc.) and both environment's
various user interfaces (Wayland & X inclusive). It's interface presents
an SDL interactive application and auxillary features are built out in
scripts. The basic interface is essentially a OSM map that can be panned,
zoomed, mainuplated, and overlayed via 'pins' which are arbitrary points
on the map which can be added by the user to mark locations. Being a
good unix citizen, the core application does one thing well, **only**
focusing on displaying the map and visual overlays, and has no extra
functionality; however Mepo plays well with other applications and is
**scriptable** and very customizable through [Mepolang](#mepolang).

For end-users not intersted in customizing the behvaior of Mepo, the
application is bundled with **sensible defaults** including a default set
of keybindings, touch-compatible configuration, and scripts written in
plain shell which enable features such as [POI searches](#poi-searches),
[routing](#routing), and more. Throughout the rest of this guide it will
be assumed the user is making use of the default configuration and has
done no customization; but its important to realize there is a hard
disticntion between the core SDL application, Mepo, and its default
configuration and scripts which are bundled by default.

## **Touch & Mobile support:**

Using Mepo on mobile linux devices such as the Pinephone, Librem 5, and postmarketOS
devices and similar is a primary usecase. Take note of the following shortcuts:

- **One finger drag:** Pan the map
- **One finger double tap:** Zoom in
- **One finger triple tap:** Zoom out
- **Pan gesture in**: Zoom in (in testing)
- **Pan gesture out**: Zoom out (in testing)
- **One finger hold:** Launch the [central menu](#the-central-menu)


## **Keyboard & Desktop support:**

Ordinary desktop usage is supported. Ordinary one finger hotkeys reference in
the mobile section also apply on the desktop; and in addition numerous hotkeys
exist such as panning with vim-style keys and direct hotkeys to launch
various scripts. You can reference the default [hotkeys](../src/config.zig#L18) 
by studying the default configuration.


## **The Central Menu**

Since most auxillary features such as routing, POI searches, etc. are
built out in shellscripts (which utilize dmenu, rofi etc.); the central
menu provides a central way to launch different scripts [on mobile]()
via touch or [on the desktop]() without having to rember numerous hotkeys.

Here's an explation of the options are available in the central menu:

- **Debug: API**
  - Allow you to enter custom [Mepolang]() commands to execute.
- **Download: clear download queue**
  - If you had previously started a region for download queueing, this will
    cancel that operation.
- **Download: current bounding-box (non-interactive)**
  - Automatically queue whatever you're viewing currently on the map to
    download all tiles.
  - All zoom levels higher then whatever the current viewport is showing
    will be downloaded.
- **Download: custom region (interactive)**
  - Search nominatim for a custom region to download and allows the user
    specify zoom levels as well.
- **POI Search: via Nominatim**
  - Search for POIs via a nominatim search query and drop pins on the
    map. Pins will be fed into pin group 1 (thus showing as blue dots
    on the map).
  - See [POI Searches]() for more info.
- **POI Search: via Overpass**
  - Search for POIs via an [overpass query]() and drop pins on the
    map. Pins will be fed into pin group 1 (thus showing as blue dots
    on the map).
  - See [POI Searches]() for more info.
- **Relocate map: via search**
  - Update the map's location by searching for a [nominatim]() query.
- **Route: via GraphHopper**
  - Route via graphopper. Pins will be fed into pin group 2 (thus showing as
    green dots on the map).
  - See [routing](#routing) for more info.
- **Route: via Public Transit**
  - Route via public transit / a specific OSM relation id.
  - See [routing](#routing) for more info.
- **Update: Online/Offline toggle**
  - If you're offline, switch to being online and visa-versa.
  - If offline bottom bar will be red; if online bottom bar will be white.
- **Route: via Public Transit**
  - Route via public transit / a specific OSM relation id.
  - See [routing](#routing) for more info.
- **Update: Tilesource**
  - Change the tilesource for the OSM tiles to download.
- **Update: Zoom**
  - Change the zoom level by specifying the number manually.


## **POI Searches**

POI searches placeholder. Explain both nomininatim & overpass scripts here.

## **Routing**

Routing placeholder. Explain graphhopper & OSM relation scripts here.

## **Autoloading preferences**

Autoloading preference placeholder.

## **Offline Usage**

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


## **Mepolang**

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
