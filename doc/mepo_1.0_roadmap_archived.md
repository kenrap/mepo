## **Roadmap to 1.0 release**

- **Milestone 1: Overall Stability** (Complete: 10/31/2021, tag: 0.1)
  - **Done:**
    - Improve current stability of the application and resolve intermittent
      crashes related to tile downloading.
    - Implement tile downloading retry logic and handle case where user is
      offline gracefully
    - Error check invalid PNG tile data received from tile servers & loaded
      from filesystem.
    - Rework consistency of allocator passing (e.g. remove ad hoc allocators,
      ensure all allocations based on using top-level allocator via arena
      allocation).
    - Rework blitting logic to be more intelligent about not drawing off-screen
      entities & pins.
    - Implement LIFO for downloading queue: viewport tiles should always take
      priority before long-queued off-screen tiles.
    - Refactor error handling logic & use utility function rather than zig
      dbg.
    - Implement togglable text debug message overlay to provide user feedback
      right in UI when operations like shell pipe fail.
    - Add togglable help text overlay to show current results of bind_key
      (keybindings table) mapping in UI.
    - Fix bug where negative latitude values fail to round-trip between
      lat-to-y / y-to-lat conversion functions.
    - Implement debug mode preference or similar to control verbosity of
      debugging STDERR messages.
    - Resolve existing memory leaks in the application.
    - Provide an initial tag for package maintainers (0.1).
- **Milestone 2: Offline Mode & Non-Interactive Downloading**
  (Complete: 12/06/2021, tag: 0.2)
  - **Done:**
    - Add error handling logic to existing bounding-box based Mepolang download
      command to ensure valid bounding-box provided by user.
    - Rework main application / boot logic to enable fully non-interactive mode
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
    - Create Mepolang command to selectively clear download cache so
      tiles can be updated if outdated. (Note: decided to implemented expiry
      seconds preference instead)
    - Add radius-based download command allowing user to download tiles based on
      coordinate with a given radius (km distance) for specified zoom-levels.
    - Add distance to lat-lon conversion functions to assist in above (along
      with unit tests) and to later be used for measuring distance between
      pins in ordered groups.
- **Milestone 3: Powerful, Robust Pin API** (Complete: 01/30/2022, tag: 0.3)
  - **Done:**
    - Correct pin-selection mode cycling to properly respect delta values.
    - Allow ability to associate metadata with pins.
    - Fix existing pin bugs (e.g. title not showing properly & brittleness).
    - Allow pin groups to be either ordered or unordered, ordered pin groups
      show in UI with connecting lines (thus enabling lightweight navigation).
    - Implement distinction between structural pins and informational pins for
      ordered pin groups wherein structural pins are the nodes in a way and
      informational pins can be used for navigational cues.
    - Add script to add pins based on Nominatim bounding box results in
      addition to the existing Overpass pin script.
    - Implement bind_click Mepolang API command to run arbitrary Mepolang
      on clicking specific button (left, right click) 1-n times. Will enable
      more sophisticated scripts (e.g. such as click to define points in
      custom route / ordered pin group) in future.
    - Add support for click pin to activate.
    - Add pin groups and extend API as such so user can visually distinguish
      groups; for example one pin group may be bookmarks, another for a search,
      another for current location.
    - Implement command for removing specific pins based on handle.
    - Add ability to cycle through pins based on both: viewport visible pins
      and all pins.
    - Add script to convert XML Relation & Way from OSM API into ordered
      pin group(s) for testing purposes. Also should help for transit-specific
      and other overlays etc. (Implemented as overpass relation lookup instead
      as XML response doesn't have coordinates for each node entry - effect is
      same)
- **Milestone 4: Wayland & Mobile Support** (Complete: 3/22/2022, tag: 0.4)
  - **Done:**
    - Improve support for pinch-to-zoom using SDL multitouch gesture API to be
      more reliable and test on PinePhone & mobile devices.
    - Rework pinch-to-zoom to not be hardcoded but to instead use new Mepolang
      command (bind_gesture).
    - Add support for rotate gesture via SDL multitouch gesture API and expose
      as part of bind_gesture command.
    - Currently scripts for location search, bounding-box search,
      and similar use dmenu (X-based); integrate wofi, bemenu, or a similar
      tool for Wayland. Dynamically determine which menuing system to use
      in scripts.
    - Allow binding left hand/right hand side of pin overlay via new
      (bind_button) command and set to pin_cycle by default. Thus enabling
      touch-based pin-cycling for navigation. (Implemented buttons as
      arbitrary used-defined bar on bottom right corner)
    - Build out context-menu to be used in mobile-context allowing functionality
      triggered on desktop via keybindings for search etc. to be simply triggered
      on mobile.
    - Add to default Mepolang configuration trigger to open context-menu either
      via bind_gesture or bind_click.
    - Perform testing and make fixes as necessary on most common UIs on
      postmarketOS. Primarily test and ensure compatibility with Phosh
      (mobile Wayland), Swmo (mobile Wayland), Sxmo (mobile X), Sway
      (desktop Wayland), and i3 (desktop X) as these 5 environments encompass
      large userbases and represent the 4 different combinations of
      mobile/desktop & X/Wayland that should all have first-class support.
    - Rework SDL defaults (window expose, winch, default sizing etc.) to ensure
      greatest cross-compatibility between environments.
- **Milestone 5: UI Niceties** (Complete: 8/15/2022, tag: 0.5)
  - **Done:**
    - Add visual per-tile-downloading progress-indicators.
    - Add support for pasting / copying current coordinates from the system
      clipboard and ensure compatibility in both Wayland & X.
    - Rework main application event loop to handle STDIN file descriptor in
      parallel to current SDL events processing. So commandline of application
      can thus be used non-interactively / scripted. Also helpful for debugging.
    - Gracefully handle switching tile sources (e.g. purge cache & reload).
      Should be able to switch between OSM/bikemaps/stamen etc. without
      glitches.
    - Add routing script based on GraphHopper, OpenRouteService, or similar
      to parse GeoJSON LineString API response into an ordered pin group. Thus
      allowing for point-to-point navigation.
    - Implement save state / restore state Mepolang API command that dumps
      current state to file (as Mepolang) / and can restore via loading file.
    - Make shell pipe non-blocking (e.g. don't freeze UI while waiting for
      result) or otherwise implement timeout so that runaway scripts don't
      freeze application.
    - Refine existing Overpass search script (provide better recommendations
      illustrating OSM tag-based flexibility).
    - Add example bookmarking script based on pin API.
    - Improve bottom status bar display to show bandwidth usage / download of
      tiles, disk, and memory usage.
    - Finalize Mepolang 1.0 API and add error checking so things don't crash
      when accessing invalid union tag etc (improve robustness of mepolang
      parser).
    - Integrate gpsd into a script to update user's current location pin and
      fallback to geoclue2 as needed.
    - Autoupdate user current location either through introducing
      bind_interval command or continously running async_shellpipe script.
- **Milestone 6: Documentation & Packaging** (Complete: 9/29/2022, tag: 1.0)
  - **Done:**
    - Add manpage documenting Mepolang commands and basic usage.
    - Add markdown-based documentation to explain mepolang commands, usage
      in parity with man page.
    - Add prefs documentation to manpage
    - Modify internals of prefset / preferences table to automatically generate
      documentation directly from code / structs.
    - Modify internals of Mepolang to include documentation directly in
      structs so that Mepolang API documentation can be automatically generated
      as a webpage for end-users.
    - Document existing scripts used for search, routing, etc. and add notes
      about how these scripts could be used offline by running Nominatim,
      Overpass, GraphHopper, etc. locally.
    - Document examples on how to write custom scripts interfacing with
      mepolang.
    - Create Alpine package and add to pmOS postmarketos-ui-* frontends.
      (Note: depends on zig which is in testing , so cannot be directly
      added at the moment and is more of a pmOS admin decision)
    - Work with maintainers of mobile Linux (& PinePhone) UIs to get
      Mepo integrated properly.
    - Tag 1.0 release.
    - Package-split current `scripts/` directory to allow separate packages
      for mepo and mepo-scripts. The former only will contain the base
      application (Zig) executable; the latter will contain auxiliary scripts.
- **Milestone 7: Documentation Website** (Complete: 9/30/2022)
  - **Done:**
    - Development of a documentation website
    - Docs section: highlighting the various end-user documentation guides &
      tutorials (such as the installation guide, userguide, scripting guide,
      mepolang documentation etc.).
    - Contribute section: information on how to contribute,
      links to repository, bug tracker, mailing list, IRC, and details on
      how to get involved.
    - Videos section: to demonstrate both end-user functionality (such as with
      the [video created for 0.4](https://media.lrdu.org/mepo_demos/mepo_demo_0.4.webm)),
      and additionally this section could host new screencasts showing how to
      hack on mepo (e.g. examples of showing editing mepolang configuration
      and showing the end result; rather then just 'end-user' functionality
      as was the target with the 0.4 demo video).
    - Screencasts for userconfig/scripts
    - General QA pass on entire website typos/links/etc
- **Milestone 8: Additional Mobile Enviroments Compatibility - PlaMo & Lomiri** (Complete: 9/29/2022)
  - **Done:**
    - Add support for PlaMo (investigate bemenu compatbility, if unavailable something.
      like zenity or another window-based input method may be used). Note: integrated
      via zenity
    - Investigate & possibly add Flatpak compatability as this will likely
      be the simplest packaging route for Ubuntu Touch etc. Note: Flatpak created
      and added to Flathub.
    - Add support for Lomiri (Note: cut support due to incompatbilites with Mir, see mailing list note
      for more details)
