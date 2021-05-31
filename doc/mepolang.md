# **mepolang**

## **Overview:**

Mepo features a command language API for IPC that can be sent to its
process via STDIN continually. Through this mechanism you can control Mepo
using an external script or by simply piping in a configuration on boot
(as in `cat config | mepo`).  You can also use a FIFO for convienence
sake as well.  Many of Mepo's commands play nice together and also a
good place to look to understand mepolang's utilization is the [default
config](../config).

**Note:** This document is a working draft will be finalized upon reaching tagging
1.0. Expect there to be breaking changes between tagged releases.

## **Syntax:**

**Example:**
- ```sh
  commandname textarg [multi word arg] 2;
  commandname2 arg 8.373 anothertextarg;
  ```

**Rules:**

- Each statement is made up of multiple tokens.
- Each mepolang command should be terminated by a semicolon.
- The first token in a statement is always the commandname.
- Tokens should be seperated by whitespace
- Each token is either:
  - Text
    - If you want to use a space within an argument use [ square brackets ] to create a multiword token
  - Number (A floating point number)

## **Commands:**

- **bind_key** [mepolang:text]:
  - Binds pressing a keyboard key to run another mepolang command.
- **center_on_coords [lat:number] [lon:number]**:
  - Navigates to the given latitude and longitude placing point in center of the screen.
- **center_on_mouse**:
  - Reposition the viewport to be centered on the current position of the mouse.
- **move_relative** [x:number] [y:number]:
  - Move the viewport by the given x and y relative numbers.
- **pin_add** [lat:number] [lon:number] [name:text]:
  - Add a pin at the given latitude and longitude with the name.
- **pin_cycle** [index:number]:
  - Focus the next or previous pin based on the index (relative). Repositions the
    viewport's center to lie ontop of the pin.
- **pin_deactive**:
  - Deactive pin-selection mode.
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
    be mepolang command(s).
- **zoom_relative** [index:number]:
  - Adjust the current zoom level by the given index.
