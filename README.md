# **Mepo**

> **Funding information:** Consider supporting my work on mepo if you 
> want to help support my current development of mepo!
> I'd like to take a few months off from my dayjob to get
> mepo over the finish line and to reach 1.0 (see goals below). 
> If I can get a modicum of financial support
> behind me for this, I will make this a reality, greatly accelerating
> the development pace! [Donate here / Funding Link]()!

---


Mepo is a fast, lightweight, and hackable OSM map viewer for desktop linux
& mobile linux devices (like the Pinephone, Librem 5 etc.) and both environment's 
various user interfaces (Wayland & X inclusive). Mepo works both offline and online,
can be controlled entirely through the keyboard, and offers a UNIX-philosophy
inspired design, exposing a command language called mepolang.

Note, mepo is currently in a pre-alpha state although quickly making progress.
An initial first tagged release (0.1), is scheduled to be released in short
order (within about a month or so). See below for goals, the high-level
current progress of mepo, and path to 1.0.

[Videos of User Interface]()

## **Goals / overview of Mepo:**
- **Fast & usable in resource-constrained enviroments**:
  - Mepo **launches quickly and runs quickly** on the Pinephone and other
    resource-constrained devices. 
  - Most other map applications for Linux render webviews; Mepo renders using
    SDL which keeps things **fast** and lightweight; also as a bonus: portable.
- **UNIX-philosophy inspired design - scriptability via mepolang**:
  - Mepo's UI is built **to do one thing well**: download/render maps. 
    Extra functionality is enabled via its command language (mepolang).
  - Reduces overall application logic complexity, handing over to 
    shell-scripting integeral features like map bounding-box & location search,
    bookmarks, dropping pins, rebinding keys, and more
  - Existing OSM tools for search like the [Nomatim]() & [Overpass]() APIs are
    integrated through [bundled shell scripts](); customize to your heart's content.
- **Offline operation as a first-class feature**:
  - Downloading of maps for later offline use can be done non-interactively
    through mepolang.
  - Offline usage is a primary usecase and should be treated as such, we 
    can't assume a user is always online.
- **Supports touch AND keyboard-oriented operation**:
  - A map application must ofcourse be usable with a mouse / touch, but
    the keyboard as a tool for map navigation has been underlooked in
    other applications.
  - Mepo provides vi-like (& customizable) keybindings out-of-the-box 

## **High-level overview of currently implemented feature of mepo:**
- Fast SDL-based rendering of OSM map tiles
- Downloading of OSM map tiles from user-specified source (default: OSM Maps)
- Minimal command-language for 'mepolang' in which all core-functionality built out
- Pan via mouse, double tap to zoom, right click or triple left click to zoom out
- Vi-like keys (though customizable) for panning, zooming, center on mouse, etc.
- Navigate to different regions via shell-script (nomatim API based)
- Drop pins / search for POI via shell-script (overpass API based)
- Cycle through pins using hotkeys (vim-like n/p, though customizable)
- Switch tile URL source via shell-script (toggle between OSM, Bike maps, Google)
- Dynamic tile caching to filesystem / offline-maps once downloaded
- Run API commands (mepolang) via command prompt (dmenu) or via STDIN

## **Roadmap to 1.0 release:**
- Goal 1: Overall Stability
  - Current stability of the application should be improved and crashes should
    be non-existent
  - Memory allocations / deallocations should be careful tracked and managed
  - Fix downloading bugs: make downloading tiles logic more robust, currently,
    tiles downloading can occasionally / get stuck
- Goal 2: Offline / Noninteractive Downloading
- Goal 3: Powerful, Robust Pin API
  - Pipe current state (lat/lon etc.) to scripts in shellpipe mepolang command
  - Pin-selection mode
    - Cycle currently active pin (with p/n keys)
    - Reposition map to pin
  - Click pin to activate
  - Fix overpass search script once above point addressed
  - Commands for removing specific pins
  - Command for purging all pins
- Goal 4: Wayland Support
  - Currently scripts for URL source selection, 
- Goal 5: UI Niceties
- Goal 6: Documentation & Packaging
  
- Customization on STDIN via mepolang (non-continuous)
- Offline-downloading of tiles within radius (meploang command)
- Allow application to read mepolang commands at runtime via STDIN
- Ability to associate metadata with pins (and show that metadata in UI)
- Per-tile-downloading progress-indicators
- Bottom status bar to show current bandwidth usage / download of tiles
