# User Guide

> **Disclaimer**: This guide is a work-in-progress and not complete!

## Table of contents:
- [Basic Interface Overview](#basic-interface-overview)
- [Touch & Mobile support](#touch-mobile-support)
- [Keyboard & Desktop support](#keyboard-desktop-support)
- [Visual UI Overview](#visual-ui-overview)
- [The UI Button Bar](#the-ui-button-bar)
- [The Central Menu](#the-central-menu)
- [POI Searches](#poi-searches)
- [Routing](#routing)
- [Repositioning the map](#repositioning-the-map)
- [Autoloading preferences](#autoloading-preferences)
- [Offline Usage](#offline-usage)
- [Using the `tile_cache_network` parameter](#using-the-`tile_cache_network`-parameter)
- [Mepolang](#mepolang)
- [CLI Options](#cli-options)

## Basic Interface Overview

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

## Touch & Mobile support

Using Mepo on mobile linux devices such as the Pinephone, Librem 5, and postmarketOS
devices and similar is a primary usecase. Take note of the following shortcuts:

- **One finger drag:** Pan the map
- **One finger double tap:** Zoom in
- **One finger triple tap:** Zoom out
- **Two fingers pan gesture in**: Zoom in (in testing)
- **Two fingers pan gesture out**: Zoom out (in testing)
- **Three fingers rotate gesture clockwise**: Increase UI fontsize (in testing)
- **Three fingers rotate gesture counterclockwise**: Decrease UI fontsize (in testing)
- **One finger hold:** Launch the [central menu](#the-central-menu)

## Keyboard & Desktop support

Ordinary desktop usage is supported. Ordinary one finger hotkeys reference in
the mobile section also apply on the desktop; and in addition numerous hotkeys
exist such as panning with vim-style keys and direct hotkeys to launch
various scripts. You can reference the default [hotkeys](../src/config.zig#L18) 
by studying the default configuration.

## Visual UI Overview

**TODO** Add visual diagram explaining difference components of UI
(buttonbar, bottom bar, pin overlay, pins, etc.)

## The UI Button Bar

The UI feature a bar of buttons in the default configuration indicated
as text aligned in a bar on the bottom of the screen. Under the hood this is
actually built out using the `bind_button` mepolang command; so if you want
to add your own custom buttons (tied to userscripts, etc.) this is doable.

Here's an explanation of the provided script accessible in the button
bar in the default config:

- **Menu**: Launch the [central menu]() for additional actions
- **Relocate**: Relocate map via nominatim
- **Nominatim**: Nominatim POI Search script
- **Overpass**: Overpass POI Search script
- **Download**: Download current viewport (all tiles in current/higher zoom levels)

## The Central Menu

Since most auxillary features such as routing, POI searches, etc. are
built out in shellscripts (which utilize dmenu, rofi etc.); the
central menu provides a central way to launch different scripts [on
mobile](#strongtouch-amp-mobile-supportstrong) via touch or [on the
desktop](#strongkeyboard-amp-desktop-supportstrong) without having to
rember numerous hotkeys.

Here's an explation of the options are available in the central menu:

- **Download: clear download queue** (w):  Clears the current download cache (background downloading of tiles).  
- **Download: custom region (interactive)** (q):  Queues the current bounding box / viewport of the map to be downloaded in the background. Interactive, in that user is prompted for the minimum and maximum zoom-level to be downloaded.  
- **Download: current bounding-box (non-interactive)** (Q):  Queues the current bounding box / viewport of the map to be downloaded in the background. Non-interactive, in that user is not prompted for zoom-level etc. All zoomlevels equal to and higher then the current zoom level are downloaded.  
- **Pin editor: Edit, save, and restore pin metadata** (f):  Provides comprehensive pin editing via interactive menuing, allowing the user to add and remove pins,as well as edit pin metadata. Uses the `filedump` command functionality to extract pin data. Script is designed to be used asychronously via `shellpipe_async`.  
- **Update: Fontsize** (Z):  Updates the fontsize of the UI prompting the user for the input size. Presents menuing prefilled between sizes 12 and 30.  
- **Update: Online/Offline toggle** (m):  Toggles the UI between offline and online mode (e.g. flipping the preference tile_cache_network).  
- **Update: Tilesource** (u):  Updates the tilesource for the map to pull from. Note %1$d, %2$d, and %3$d are used to indicate X, Y, and Z variables respectively. Presents menuing with presets for OSM Maps, Stamen, OpenCycleMap etc.  
- **Update: Zoom** (z):  Updates the zoom level based on users input. Presents menuing to  pick from zoom levels between 1 and 16.  
- **Relocate map: via search** (g):  Repositions the map latitude and longitude based on a Nominatim search query. Presents menuing to prompt user for input location and pick from Nominatim results.  
- **Route: via GraphHopper** (r):  Allows user to determine a route between two points via the publically accessible GraphHopper instance. Presents menuing to prompt user for origin and destination points. The cursor (e.g. the position of the mouse or on mobile the last clicked point - e.g. in case of click-hold functionality) and the centerpoint (where the crosshair is) may be used as origin or destination points as an alternative to named entries. Named entry searches use Nominatim to lookup the user input query. Resulting route is placed into pin group 1 as an ordered pin group wherein instructional pins show each direction in the route.  
- **Route: via OSM Relation / Public Transit** (R):  Drops pins on the map in pin group 1 for the given OSM relation ID. This can be used for general routing for any OSM relation (such as a subway, bus route, or similar). Presents menuing to prompt for the input OSM relation ID.  
- **POI Search: via Nominatim** (G):  Searches for points of intrest via the publically accessible Nominatim API based on the current viewport.  Presents menuing to prompt for input overass query. Drops pins on the map for the resulting found points of intrest in pin group 0; purging any previous pins in in group 0.  
- **POI Search: via Overpass** (b):  Searches for points of intrest via the publically accessible Overpass API based on the current viewport.  Presents menuing to prompt for input overass query. Drops pins on the map for the resulting found points of intrest in pin group 0; purging any previous pins in in group 0.  
- **Location Pin: Center on user location** (x):  Determinines the user location via GPSD, Geoclue, or Mozilla Location services. When provided with no argument runs the function `droppinactivateandcenter` which both drops a pin on the map and centers the map. Meanwhile the function `droppin` can be used in isolation to only drop a pin on the map. This script may be used synchronously or asynchronoulsly; within the default config `droppin` is used asynchronounously via `shellpipe_async`.  


## POI Searches

Points of intrest within the current viewport (bounding-box) can
be searched both via [Nominatim](https://nominatim.org/) or via
[Overpass](https://wiki.openstreetmap.org/wiki/Overpass_API) using the
default included scripts. Each of these methods has its advantages
and disadvantages. Generally speaking, for specific **name-based**
searches within a region, you should use Nominatim; while for **flexible
OSM-tag-based** searches you should use Overpass.

As described above, **Nominatim** excels at **name based searches**. For
example if you wanted to find a restraunt called "Joe's Pizza" you could
type this directly into the Nominatim POI search script prompt. Or
similarly to find a starbucks, you could just type in "starbucks" in
the Nominatim prompt.

Meanwhile, **Overpass** is more powerful and suited then Nominatim for
POI searches **based on OSM tags**; for example if you wanted to find
all coffeshops, (rather then just a specific name of a coffeshop such as
"starbucks" in the previous example) you could search for the general
OSM tag `[amenity=cafe]`. This will find all OSM relations matching this
tag within the current bounding box. A number of prepopulated OSM tags
are available within the provided Overpass script; however if you want
to search any custom OSM tag, simply enter it and this will work just
the same.

## Routing

**TODO**
Routing placeholder.
Explain graphhopper & OSM relation scripts here.

## Repositioning the map

The map view will start wherever is set in the default configuration or
optionally you can overload this default location (see the next section
for autoloading preferences).

To reposition the map while mepo is already running you can use the
provided menu entry `Relocate map: via Nominatim` entry to search
nominatim to determine a new location to set for the map. Using this
script simply enter the name of a region (city, state, country, etc.) and
Nominatim will be queried for matching targets. Select a target to
reposition the map accordingly.

## Autoloading preferences

Within the default config, the file located at `~/.mepo/config` is loaded
from the filesystem by default when starting mepo. You can put user-specific
configuration here that will override the default configuration.

Example `~/.mepo/config`:

```sh
prefset_n lat 42.3608;
prefset_n lon -71.0573;
pin_groupprefset 3 active 1;
pin_add 3 0 42.355 -71.0780 [foopin] [foopin];
prefset_n zoom 15;
```
In the above example, the map is repositioned to Boson, MA, US and an
arbitrary bookmark pin named foopin is placed on the map.

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
process via STDIN continually. See the [Mepolang]() page and [scriting
guide]() for more information on mepolang usage.

## CLI Options

- `mepo -docmd`: Print markdown documentation for Mepolang to STDOUT
- `mepo -docman`: Print manpage documentation for mepolang API to STDOUT
- `mepo -i`: Read mepolang from STDIN continually
- `mepo -e`: Enable debug mode to log messages to STDERR
- `mepo -ndc`: Disable default config, e.g. not wanting defaults bindings etc.. like `cat my_config | mepo -ndc`
- `mepo -sw`: Use software renderer rather then default GPU/hardware based renderer
- `mepo -v`: Print version number
- `mepo -h`: Print this help text
- `mepo -d`: Non-interactively download tiles for given range
