# **Mepolang**

> **Note:** This document is a working draft and will be finalized upon tagging
> the 1.0 release of Mepo. Expect there to be breaking changes between pre 1.0 tagged releases.

## **Overview:**
- Mepolang is Mepo's command language API for IPC that can be sent to its process via STDIN continually.
- Through this mechanism you can control Mepo: using an external script, by simply piping in a configuration on boot, or by using a FIFO.
  - E.g. `./my_script | mepo`
  - Or `cat config | mepo`
  - Or `mkfifo foo; cat foo | mepo`
- Upon the 1.0 release it is planned that there will be two commands included to run Mepo: `mepo_raw` and `mepo` wherein `mepo` will just be a script that runs `cat default_config | mepo_raw`.
  - The [default config](../config) provides some nice mobile & desktop friendly settings, however things are entirely customizable through mepolang by providing your own config.
- Many of Mepo's commands play nice together. A good place to look to understand mepolang's utilization is the [default config](../config).
  - For example `bind_key` actually also takes mepolang text to run as an argument.
  - Similarly the result of `shellpipe`, runs mepolang text given the STDOUT result of a (user) [shellscript](../scripts).

## **Syntax:**

**Example:**
```sh
commandname textarg [multi word arg] 2;
commandname2 arg 8.373 anothertextarg;
```
---
 
**Rules:**

- Each statement is made up of multiple tokens.
- Each mepolang command should be terminated by a semicolon.
- The first token in a statement is always the command name.
- Tokens should be separated by whitespace.
- Each token is either:
  - Text
    - Just plain text, by default assumed to be a single word.
    - If you want to use a space within an argument use `[ square brackets ]` to create a multiword token.
  - Number
    - A floating point number, either decimal (e.g. `3.77`) or whole (e.g. `3`).

## **Commands:**

- **bind_key [mod:text] [key:text] [mepolang:text]**:
  - Binds pressing a keyboard key to run another mepolang command.
- **center_on_coords [lat:number] [lon:number]**:
  - Navigates to the given latitude and longitude placing point in center of the screen.
- **center_on_mouse**:
  - Reposition the viewport to be centered on the current position of the mouse.
- **download_bbox** [a_lat:number] [a_lon:number] [b_lat:number] [b_lon:number] [zoom_min:number] [zoom_max:number]:
  - Queues for downloading all tiles within the bounding box denoted between a lat/lon and b lat/lon for zoom levels between zoom_min/zoom_max
- **move_relative** [x:number] [y:number]:
  - Move the viewport by the given x and y relative numbers.
- **pin_add** [lat:number] [lon:number] [name:text]:
  - Add a pin at the given latitude and longitude with the given name.
- **pin_cycle** [index:number]:
  - Focus the next or previous pin based on the index (relative). Repositions the
    viewport's center to lie ontop of the pin.
- **pin_deactivate**:
  - Deactivate pin-selection mode.
- **pin_purge**:
  - Clear all currently added pins.
- **prefset** [prefname:text] [value:text_or_number]:
  - Sets the preference named text to the value. Currently supported preferences:
  - | prefname       | type   | description                                                   |
    | ---            | ---    | ---                                                           |
    | debug_global   | number | Shows (1) or hides (0) global debug text.                     |
    | debug_tiles    | number | Shows (1) or hides (0) per-tile debug text.                   |
    | zoom           | number | Sets the zoom level of the map.                               |
    | crosshair_on   | number | Show (1) or hides (0) the center crosshair.                   |
    | crosshair_size | number | Determines the size pixels of the center crosshair.           |
    | tile_cache_dir | text   | Determines the directory for downloaded tites to be saved to. |
    | tile_cache_url | text   | Determines the URL of the tileserver to pull from.            |
- **shellpipe** [path_to_script:text]:
  - Executes the script given in a subshell; the result given to STDOUT may optionally
    be mepolang command(s) which are then subsequently run. See [examples](../scripts).
- **zoom_relative** [index:number]:
  - Adjust the current zoom level by the given index.
