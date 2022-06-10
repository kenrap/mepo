# Mepo: **User Guide**

> **Disclaimer**: This guide is a work-in-progress and not complete!

## **Table of contents:**
- [Installation](#stronginstallationstrong)
- [Basic Interface Overview](#strongbasic-interface-overviewstrong)
- [Touch & Mobile Support](#strongtouch-amp-mobile-supportstrong)
- [Keyboard & Desktop Support](#strongkeyboard-amp-desktop-supportstrong)
- [Visual UI Overview](##visual-ui-overview)
- [The UI Buttonbar](##the-ui-button-bar)
- [The Central Menu](##strongthe-central-menustrong)
- [POI Searches](#strongpoi-searchesstrong)
- [Routing](#strongroutingstrong)
- [Repositioning the map](#strongrepositioning-the-mapstrong)
- [Autoloading preferences](#strongautoloading-preferencesstrong)
- [Offline Usage](#strongoffline-usagestrong)
- [Mepolang](#strongmepolangstrong)
- [Debugging](#strongdebuggingstrong)

## **Installation**

Mepo is available currently for postmarketOS (edge) and NixOS.
To install on postmarketOS, depending on your targeted enviroment install
either `mepo-wayland`, `mepo-xorg`, or `mepo-framebuffer`. For Sxmo or desktop
X use mepo-xorg,  for Phosh, Swmo, sway, or desktop wayland use mepo-wayland, 
or for framebuffer use `mepo-framebuffer`

Examples install command:
```sh
apk add mepo-wayland
```

On Phosh, a new icon will appear for Mepo, and in S{x,w}mo, mepo will
appear in the applications menu. To launch on desktop, you can directly
run the command `mepo`.

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

## **Touch & Mobile support**

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


## **Keyboard & Desktop support**

Ordinary desktop usage is supported. Ordinary one finger hotkeys reference in
the mobile section also apply on the desktop; and in addition numerous hotkeys
exist such as panning with vim-style keys and direct hotkeys to launch
various scripts. You can reference the default [hotkeys](../src/config.zig#L18) 
by studying the default configuration.

## **Visual UI Overview**

**TODO** Add visual diagram explaining difference components of UI
(buttonbar, bottom bar, pin overlay, pins, etc.)

## **The UI Button Bar**

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

## **The Central Menu**

Since most auxillary features such as routing, POI searches, etc. are
built out in shellscripts (which utilize dmenu, rofi etc.); the
central menu provides a central way to launch different scripts [on
mobile](#strongtouch-amp-mobile-supportstrong) via touch or [on the
desktop](#strongkeyboard-amp-desktop-supportstrong) without having to
rember numerous hotkeys.

Here's an explation of the options are available in the central menu:

- **Debug: API**
  - Allow you to enter custom [Mepolang](#strongmepolangstrong) commands to execute.
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
  - See [POI Searches](#strongpoi-searchesstrong) for more info.
- **POI Search: via Overpass**
  - Search for POIs via an [overpass query]() and drop pins on the
    map. Pins will be fed into pin group 1 (thus showing as blue dots
    on the map).
  - See [POI Searches](#strongpoi-searchesstrong) for more info.
- **Relocate map: via search**
  - Update the map's location by searching for a [Nominatim](https://nominatim.org/) query.
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

## **Routing**

**TODO**
Routing placeholder.
Explain graphhopper & OSM relation scripts here.

## **Repositioning the map**

The map view will start wherever is set in the default configuration or
optionally you can overload this default location (see the next section
for autoloading preferences).

To reposition the map while mepo is already running you can use the
provided menu entry `Relocate map: via Nominatim` entry to search
nominatim to determine a new location to set for the map. Using this
script simply enter the name of a region (city, state, country, etc.) and
Nominatim will be queried for matching targets. Select a target to
reposition the map accordingly.

## **Autoloading preferences**

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

### Debugging

By default debug messages are disabled. To start mepo with debugging via
STDERR use the CLI flag `-e`. E.g. as:

```
mepo -e
```
