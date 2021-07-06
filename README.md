# **Mepo**

> **Note:** Mepo is currently in an alpha state although quickly making progress.
> An initial first tagged release (0.1), is scheduled to be released in short
> order (within less then a month or so). See below for the high-level goals,
> current state of Mepo, the path to 1.0, and information on contributing!

[![mepo_demo.gif](mepo_demo.gif)](http://media.lrdu.org/mepo_demos)

Mepo is a fast, simple, and hackable OSM map viewer for desktop linux
& mobile linux devices (like the Pinephone, Librem 5 etc.) and both
environment's various user interfaces (Wayland & X inclusive). Mepo
works both offline and online, features a minimalist both touch/mouse
and keyboard compatible interface, and offers a UNIX-philosophy inspired
underlying design, exposing a powerful command language called [mepolang](doc/mepolang.md)
capable of being scripted to provide things like custom bounding-box
search scripts, bookmarks, and more.

[Videos of User Interface](http://media.lrdu.org/mepo_demos)

## **Goals / overview of Mepo:**
- **Fast & usable in resource-constrained environments**:
  - Mepo **launches quickly and runs quickly** on the Pinephone and other
    resource-constrained devices. 
  - Mepo renders using SDL which keeps things **fast** and lightweight;
    also as a bonus: portable.
  - Built in a non GC'd language ([Zig](https://ziglang.org/)) with an aim toward careful
    memory usage and allocations/deallocations
- **UNIX-philosophy inspired design - scriptability via [mepolang](doc/mepolang.md)**:
  - Mepo's UI is built **to do one thing well**: download & render maps. 
    Extra functionality is enabled via its command language / API (mepolang).
  - Reduces overall application logic complexity, handing over to 
    shell-scripting integral features like map bounding-box & location search,
    bookmarks, dropping pins, rebinding keys, and more.
  - Existing OSM tools for search like the [Nominatim](https://nominatim.org/) & [Overpass](https://wiki.openstreetmap.org/wiki/Overpass_API) APIs are
    integrated through [bundled shell scripts](./scripts); customize to your heart's content
    or write your own scripts for things like bookmarking etc.
  - Bundled scripts utilize existing tools like [dmenu](https://tools.suckless.org/dmenu/)
    for user input and list selection rather then implementing application-specific input logic.
- **Offline operation as a first-class feature**:
  - Downloading of maps for later offline use can be done non-interactively
    through mepolang.
  - Users can download based on a bounding-box or a user-specified radius
    from a specific point for multiple zoom levels.
  - Offline usage is a primary usecase and should be treated as such, we 
    can't assume a user is always online.
- **Supports touch AND keyboard-oriented operation**:
  - A map application must ofcourse be usable with a mouse / touch, but
    the keyboard as a tool for map navigation has been underlooked in
    in map applications.
  - Provides vi-like (& customizable) keybindings out-of-the-box.
  - Should be usable in touch-oriented environments like the Pinephone and
    similar where a physical keyboard isn't present.

## **High-level overview of currently implemented features of Mepo:**
- Fast SDL-based rendering of OSM map tiles
- Downloading of OSM map tiles from user-specified source (default: OSM Maps)
- Minimal command-language for mepolang in which all core-functionality built out
- Pan via mouse, double tap to zoom, right click or triple left click to zoom out
- Vi-like keys (though customizable) for panning, zooming, center on mouse, etc.
- Navigate to regions or addresses via shell-script (Nominatim API based)
- Drop pins / search for POI via shell-script (Overpass API based)
- Cycle through pins using hotkeys (vim-like n/p, though customizable)
- Switch tile URL source via shell-script (toggle between OSM, Bike maps, Google)
- Dynamic tile caching to filesystem / offline-maps once downloaded
- Run API commands (mepolang) via command prompt (dmenu) or via STDIN (non-continual)
- Basic pinch-to-zoom via SDL multitouch API on Pinephone / mobile
- Piping of current state (lat/lon & bbox) to scripts in shellpipe command
- Basic noninteractive tile downloading based on viewport bounding-box


## **Roadmap to 1.0 release:**
- **Milestone 1: Overall Stability**
  - Current stability of the application should be improved and crashes should
    be non-existent.
  - Fix downloading bugs: make downloading tiles logic more robust, currently,
    tile downloading can occasionally / get stuck; implement retry logic.
    Error check / handle invalid data received from tileservers.
  - Memory allocations / deallocations should be careful tracked and managed.
    Debug with valgrind.
  - Rework blitting logic to be more intelligent about not drawing offscreen
    entities & pins.
  - Implement LIFO for downloading queue: viewport tiles should always take
    priority before long-queued offscreen tiles.
  - Refactor error handling logic and implement log levels for debugging.
  - Tag 0.1 release upon completion
- **Milestone 2: Offline Mode & Noninteractive Downloading**
  - Rework main application / boot logic to enable fully noninteractive mode
    (free of SDL-context) to allow for CLI-based downloading of tiles.
  - Add error handling logic to existing bounding-box based mepolang download
    command to ensure valid bounding-box provided by user.
  - Add radius-based download command allowing user to download tiles based on
    coordinate with a given radius (km distance) for specified zoom-levels.
  - Add a shell script to download interactively based on Nominatim search
    query result so you can say download an entire city for example.
  - Create mepolang command to selectively clear download cache so
    tiles can be updated if outdated.
- **Milestone 3: Powerful, Robust Pin API**
  - Correct pin-selection mode cycling to properly respect delta values.
  - Add ability to cycle through pins based on both: viewport visible pins and all pins.
  - Add support for click pin to activate.
  - Implement command for removing specific pins based on handle.
  - Allow ability to associate metadata with pins.
  - Fix existing pin bugs (e.g. title not showing properly & brittleness).
  - Add pin groups and extend API as such so user can distinguish groups;
    for example one pin group may be bookmarks, another for a search,
    another for current location.
  - Allow pin groups to be either ordered or unordered, ordered pin groups
    show in UI with connecting lines (thus enabling lightweight navigation).
  - Add script to add pins based on Nominatim results in addition to
    existing Overpass pin script.
- **Milestone 4: Wayland & Mobile Support**
  - Improve support for pinch-to-zoom using SDL multitouch gesture API to be
    more reliable and test on Pinephone & mobile devices.
  - Currently scripts for location search, bounding-box search,
    and similar use dmenu (X-based); integrate wofi or a similar tool
    for Wayland. XWayland can be used in intermediate term. Dynamically
    determine which menuing system to use in scripts.
  - Add a simple gesture detection binding mepolang API (bind_gesture) command
    similar to lisgd to facilitate opening a context menu on mobile.
  - Build out context-menu to be used in mobile-context allowing functionality
    triggered on desktop via keybindings for search etc. to be simply triggered
    on mobile.
  - Perform testing and make fixes as necessary for primary mobile UIs:
    Phosh, Sxmo, and Plasma Mobile.
- **Milestone 5: UI Niceties**
  - Rework main application event loop to handle STDIN filedescriptor in
    parallel to current SDL events processing. So commandline of application
    can thus be used noninteractively / scripted. Also helpful for debugging.
  - Gracefully handle switching tile sources (e.g. purge cache & reload).
    Should be able to switch between OSM/bikemaps/stamen etc. without
    glitches.
  - Add per-tile-downloading progress-indicators.
  - Improve bottom status bar display to show bandwidth usage / download of
    tiles, disk, and memory usage.
  - Integrate gpsd into a script to update user's current location pin and
    fallback to geoclue2 as needed.
  - Finalize mepolang 1.0 API and add error checking so things don't crash
    when accessing invalid union tag etc (improve robustness of mepolang
    parser).
- **Milestone 6: Documentation & Packaging**
  - Add manpage documenting mepolang commands and basic usage.
  - Document examples on how to write custom scripts using mepolang.
  - Modify internals of mepolang to include documentation directly in
    structs so that mepolang API documentation can be automatically generated
    as a webpage for end-users.
  - Create Alpine/pmOS package and add to postmarketos-ui-* frontends.
  - Possibly package-split current `scripts/` directory to keep dependencies
    on base even more minimal.
  - Work with maintainers of mobile linux (& Pinephone) UIs to get
    Mepo integrated properly.
  - Tag 1.0 release


## **Contributing**

Mepo is surely welcome to contributors who have experience or interest
in mobile Linux, OSM, and/or Zig. Since things are still early on in the
project, there is no dedicated ML yet, however this will come soon. In
the meantime please either email me directly and I can provide guidance
on contributing or preferably drop into our IRC channel to discuss. Also
see the [development guide](doc/develop.md).

**IRC Channel:**
#mepo on irc.oftc.net

**Contact email:**
m at milesalan.com
