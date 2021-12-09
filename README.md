# [**Mepo**](https://sr.ht/mil/Mepo/)

> **Note:** Mepo is currently in active development and while functional,
> largely intended currently for early adopters (prior to the 1.0 release).
> See below for the high-level goals, current state of Mepo, the path to
> 1.0, and information on contributing!

[![mepo_demo.gif](mepo_demo.gif)](http://media.lrdu.org/mepo_demos)

Mepo is a fast, simple, and hackable OSM map viewer for desktop linux
& mobile linux devices (like the Pinephone, Librem 5 etc.) and both
environment's various user interfaces (Wayland & X inclusive). Mepo
works both offline and online, features a minimalist both touch/mouse
and keyboard compatible interface, and offers a UNIX-philosophy inspired
underlying design, exposing a powerful command language called [mepolang](doc/userguide.md#Mepolang)
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
- **UNIX-philosophy inspired design - scriptability via [mepolang](doc/userguide.md#Mepolang)**:
  - Mepo's UI is built **to do one thing well**: download & render maps.
    Extra functionality is enabled via its command language / API (mepolang).
  - Reduces overall application logic complexity, handing over to
    shell-scripting integral features like map bounding-box searches,
    location search lookup, bookmarking, dropping pins, routing,
    rebinding keys, and more.
  - Uses single abstraction (central pin API via mepolang) for indicating
    and placing user-defined coordinates graphically on the map (e.g. same
    mechanism used generically between POI searches, bookmarks, routing, etc.)
  - Existing OSM tools for search & routing like the [Nominatim](https://nominatim.org/),
    [Overpass](https://wiki.openstreetmap.org/wiki/Overpass_API), and
    [GraphHopper](https://www.graphhopper.com/) APIs are integrated through
    [bundled shell scripts](./scripts); customize to your heart's content or
    write your own scripts for custom integrations.
  - Bundled scripts utilize existing tools like [dmenu](https://tools.suckless.org/dmenu/)
    for user input and list selection rather then implementing application-specific input logic.
- **Offline operation as a first-class feature**:
  - Downloading of maps for later offline use can be done non-interactively
    through a command-line flag.
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
- **Milestone 1: Overall Stability** (Complete: 10/31/2021, tag: 0.1)
  - **Done:**
    - Improve current stability of the application and resolve intermittent
      crashes related to tile downloading.
    - Implement tile downloading retry logic and handle case where user is
      offline gracefully
    - Error check invalid PNG tiledata received from tileservers & loaded 
      from filesystem.
    - Rework consistency of allocator passing (e.g. remove ad-hoc allocators, 
      ensure all allocations based on using top-level allocator via arena
      allocation).
    - Rework blitting logic to be more intelligent about not drawing offscreen
      entities & pins.
    - Implement LIFO for downloading queue: viewport tiles should always take
      priority before long-queued offscreen tiles.
    - Refactor error handling logic & use utility function rather then zig
      dbg.
    - Implement togglable text debug message overlay to provide user feedback
      right in UI when operations like shellpipe fail.
    - Add togglable help text overlay to show current results of bind_key
      (keybindings table) mapping in UI.
    - Fix bug where negative latitude values fail to round-trip between
      lat-to-y / y-to-lat conversion functions.
    - Implement debug mode preference or similar to control verbosity of
      debugging STDERR messages.
    - Resolve existing memory leaks in the application.
    - Provide an initial tag for package maintainers (0.1).
- **Milestone 2: Offline Mode & Noninteractive Downloading** (Complete: 12/06/2021, tag: 0.2)
  - **Done:**
    - Add error handling logic to existing bounding-box based mepolang download
      command to ensure valid bounding-box provided by user.
    - Rework main application / boot logic to enable fully noninteractive mode
      (free of SDL/Video context) to allow for CLI-based downloading of tiles.
    - Remove SDL delay from TileCache downloading logic / properly wait on file
      descriptors instead using curl_multi_wait.
    - Add a shell script to allow downloading either interactively or
      non-interactively based on Nominatim search query result so you can say
      download an entire city for example.
    - Parameterize max number of concurrent downloads as a setting accessible
      via prefset.
    - Add configuration parameter to set an offline mode; when set to true
      all tile downloading logic should no-operation for the privacy and
      bandwidth conscience.
    - Rework UI logic to adjust downloading bar to not overlap with pin details
      overlay.
    - Create mepolang command to selectively clear download cache so
      tiles can be updated if outdated. (Note: decided to implemented expiry
      seconds preference instead)
    - Add radius-based download command allowing user to download tiles based on
      coordinate with a given radius (km distance) for specified zoom-levels.
    - Add distance to lat-lon conversion functions to assist in above (along
      with unit tests) and to later be used for measuring distance between
      pins in ordered groups.
- **Milestone 3: Powerful, Robust Pin API** (In-progress)
  - **Todo:**
    - Correct pin-selection mode cycling to properly respect delta values.
    - Add ability to cycle through pins based on both: viewport visible pins
      and all pins.
    - Add support for click pin to activate.
    - Implement command for removing specific pins based on handle.
    - Allow ability to associate metadata with pins.
    - Fix existing pin bugs (e.g. title not showing properly & brittleness).
    - Add pin groups and extend API as such so user can visually distinguish
      groups; for example one pin group may be bookmarks, another for a search,
      another for current location.
    - Allow pin groups to be either ordered or unordered, ordered pin groups
      show in UI with connecting lines (thus enabling lightweight navigation).
    - Implement distinction between structural pins and informational pins for
      ordered pin groups wherein structural pins are the nodes in a way and
      informational pins can be used for navigational cues.
    - Add script to add pins based on Nominatim bounding box results in
      addition to the existing Overpass pin script.
    - Implement bind_click mepolang API command to run arbitrary mepolang
      on clicking specific button (left, right click) 1-n times. Will enable
      more sophisticated scripts (e.g. such as click to define points in
      custom route / ordered pin group) in future.
    - Add script to convert XML Relation & Way from OSM API into ordered
      pin group(s) for testing purposes. Also should help for transit-specific
      and other overlays etc.
- **Milestone 4: Wayland & Mobile Support**
  - **Todo:**
    - Improve support for pinch-to-zoom using SDL multitouch gesture API to be
      more reliable and test on Pinephone & mobile devices.
    - Rework pinch-to-zoom to not be hardcoded but to instead use new mepolang
      command (bind_gesture).
    - Add support for rotate gesture via SDL multitouch gesture API and expose
      as part of bind_gesture command.
    - Currently scripts for location search, bounding-box search,
      and similar use dmenu (X-based); integrate wofi, bemenu, or a similar
      tool for Wayland. Dynamically determine which menuing system to use
      in scripts.
    - Allow binding lefthand/righthand side of pin overlay via new
      (bind_button) command and set to pin_cycle by default. Thus enabling
      touch-based pin-cycling for navigation.
    - Build out context-menu to be used in mobile-context allowing functionality
      triggered on desktop via keybindings for search etc. to be simply triggered
      on mobile.
    - Add to default mepolang configuration trigger to open context-menu either
      via bind_gesture or bind_click.
    - Perform testing and make fixes as necessary on most common UIs on
      postmarketOS. Primarily test and ensure compatibility with Phosh
      (mobile Wayland), Swmo (mobile Wayland), Sxmo (mobile X), Sway
      (desktop Wayland), and i3 (desktop X) as these 5 environments encompass
      large userbases and represent the 4 different combinations of
      mobile/desktop & X/Wayland that should all have first-class support.
    - Rework SDL defaults (window expose, winch, default sizing etc.) to ensure
      greatest cross-compatibility between environments.
- **Milestone 5: UI Niceties**
  - **Todo:**
    - Rework main application event loop to handle STDIN filedescriptor in
      parallel to current SDL events processing. So commandline of application
      can thus be used noninteractively / scripted. Also helpful for debugging.
    - Gracefully handle switching tile sources (e.g. purge cache & reload).
      Should be able to switch between OSM/bikemaps/stamen etc. without
      glitches.
    - Add support for pasting / copying current coordinates from the system
      clipboard and ensure compatibility in both Wayland & X.
    - Add visual per-tile-downloading progress-indicators.
    - Improve bottom status bar display to show bandwidth usage / download of
      tiles, disk, and memory usage.
    - Integrate gpsd into a script to update user's current location pin and
      fallback to geoclue2 as needed.
    - Add routing script based on GraphHopper, OpenRouteService, or similar
      to parse GeoJSON LineString API response into an ordered pin group. Thus
      allowing for point-to-point navigation.
    - Refine existing Overpass search script (provide better recommendations
      illustrating OSM tag-based flexibility).
    - Add example bookmarking script based on pin API.
    - Finalize mepolang 1.0 API and add error checking so things don't crash
      when accessing invalid union tag etc (improve robustness of mepolang
      parser).
    - Implement save state / restore state mepolang API command that dumps
      current state to file (as mepolang) / and can restore via loading file.
    - Make shellpipe non-blocking (e.g. don't freeze UI while waiting for
      result) or otherwise implement timeout so that runwaway scripts don't
      freeze application.
- **Milestone 6: Documentation & Packaging**
  - **Todo:**
    - Add manpage documenting mepolang commands and basic usage.
    - Add markdown-based documentation to explain mepolang commands, usage
      in parity with manpage.
    - Document existing scripts used for search, routing, etc. and add notes
      about how these scripts could be used offline by running Nominatim,
      Overpass, GraphHopper, etc. locally.
    - Document examples on how to write custom scripts interfacing with
      mepolang.
    - Modify internals of mepolang to include documentation directly in
      structs so that mepolang API documentation can be automatically generated
      as a webpage for end-users.
    - Modify internals of prefset / preferences table to automatically generate
      documentation directly from code / structs.
    - Create Alpine package and add to pmOS postmarketos-ui-* frontends.
    - Package-split current `scripts/` directory to allow separate packages
      for mepo and mepo-scripts. The former only will contain the base
      application (Zig) executable; the latter will contain auxiliary scripts.
    - Work with maintainers of mobile linux (& Pinephone) UIs to get
      Mepo integrated properly.
    - Tag 1.0 release.

## **Funding**
[NLnet](https://nlnet.nl) has kindly awarded a grant to support Mepo's
development efforts as part of the NGI0 Discovery Fund under grant
agreement No 825322.  This funding will enable the financial support
for implementing of the roadmap to reach 1.0 as seen above. We are
very thankful to NLnet for accepting our application and making this
development possible!

## **Contributing**

Mepo is surely welcome to contributors who have experience or interest
in mobile Linux, OSM, and/or Zig.

- **Development Guide**: [here](doc/developguide.md)
- **Mailing List**: [mepo-devel](https://lists.sr.ht/~mil/mepo-devel)
- **Tickets**: [mepo-tickets](https://todo.sr.ht/~mil/mepo-tickets)
- **IRC**: #mepo on irc.oftc.net (mla is my nick)
