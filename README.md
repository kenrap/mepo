# [**Mepo**](https://sr.ht/~mil/Mepo/)

[![mepo_demo.gif](https://media.lrdu.org/mepo_demos/mepo_demo_1.0_search.gif)](http://mepo.milesalan.com/demos.html)

Mepo is a fast, simple, and hackable OSM map viewer for desktop & mobile
Linux devices (like the PinePhone, Librem 5, pmOS devices etc.) and both
environment's various user interfaces (Wayland & X inclusive). Mepo
works both offline and online, features a minimalist both touch/mouse
and keyboard compatible interface, and offers a UNIX-philosophy
inspired underlying design, exposing a powerful command language called
[Mepolang](http://mepo.milesalan.com/mepolang.html) capable of being
scripted to provide things like custom bounding-box search scripts,
bookmarks, and more.

- [Documentation Website](http://mepo.milesalan.com)
- [Demo Video on postmarketOS phone](http://mepo.milesalan.com/demos.html#mobile-demo-major-features)
- [Videos of User Interface](http://mepo.milesalan.com/demos.html)
- [Install Guide](http://mepo.milesalan.com/installguide.html)
- [User Guide](http://mepo.milesalan.com/userguide.html)
- [Mepolang](http://mepo.milesalan.com/mepolang.html)

## **Features**

- **Fast & usable in resource-constrained environments**:
  - Mepo **launches quickly and runs quickly** on the PinePhone and other
    resource-constrained devices. 
  - Mepo renders using SDL which keeps things **fast** and lightweight;
    also as a bonus: portable.
  - Built in a non GC'd language ([Zig](https://ziglang.org/)) with an aim toward careful
    memory usage and allocations/deallocations
- **UNIX-philosophy inspired design - scriptability via [mepolang](http://mepo.milesalan.com/mepolang.html)**:
  - Mepo's UI is built **to do one thing well**: download & render maps.
    Extra functionality is enabled via its command language / API (Mepolang).
  - Reduces overall application logic complexity, handing over to
    shell-scripting integral features like map bounding-box searches,
    location search lookup, bookmarking, dropping pins, routing,
    rebinding keys, and more.
  - Uses single abstraction (central pin API via Mepolang) for indicating
    and placing user-defined coordinates graphically on the map (e.g. same
    mechanism used generically between POI searches, bookmarks, routing, etc.)
  - Existing OSM tools for search & routing like the [Nominatim](https://nominatim.org/),
    [Overpass](https://wiki.openstreetmap.org/wiki/Overpass_API), and
    [GraphHopper](https://www.graphhopper.com/) APIs are integrated through
    [bundled shell scripts](https://git.sr.ht/~mil/mepo/tree/master/item/scripts); 
    customize to your heart's content or write your own scripts for
    custom integrations.
  - Bundled scripts utilize menuing and user input functionality via
    [zenity](https://help.gnome.org/users/zenity/stable/) rather then
    implementing application-specific input logic.
- **Offline operation as a first-class feature**:
  - Downloading of maps for later offline use can be done non-interactively
    through a command-line flag.
  - Users can download based on a bounding-box or a user-specified radius
    from a specific point for multiple zoom levels.
  - Offline usage is a primary usecase and should be treated as such, we 
    can't assume a user is always online.
- **Supports touch AND keyboard-oriented operation**:
  - A map application must of course be usable with a mouse / touch,
    but the keyboard as a tool for map navigation has been overlooked in
    in map applications.
  - Provides vi-like (& customizable) keybindings out-of-the-box.
  - Should be usable in touch-oriented environments like the PinePhone and
    similar where a physical keyboard isn't present.
  - Compatible across multiple Linux mobile environments including: Phosh,
    Plasma Mobile, Sxmo, and Swmo. Being written in SDL ensures good support
    and portability to other future environments as well.

## **Documentation Website**
Mepo has a documentation website which lives at: [mepo.milesalan.com](http://mepo.milesalan.com)

## **Releases**
The most current release is 1.2.1 which builds against zig 0.12.x.

The master branch currently builds against zig 0.13.x.

Details on releases are available at: [releases page](https://git.sr.ht/~mil/mepo/refs).
    

## **Funding**
Between October 2021 and October 2022, [NLnet](https://nlnet.nl) kindly
awarded a grant to support Mepo's development efforts as part of the NGI0
Discovery Fund under grant agreement No 825322.  This funding enabled the
financial support for implementing of the roadmap to reach 1.0 as seen in
[this document](./doc/mepo_1.0_roadmap_archived.md). We are very thankful to
NLnet for accepting our application and making this development possible!

## **Contributing**
Mepo is surely welcome to contributors who have experience or interest
in mobile Linux, OSM, and/or Zig.

- **Development Guide**: [here](doc/developguide.md)
- **Mailing List**: [mepo-devel](https://lists.sr.ht/~mil/mepo-devel)
- **Tickets**: [mepo-tickets](https://todo.sr.ht/~mil/mepo-tickets)
- **IRC**: #mepo on irc.oftc.net (mla is my nick)
