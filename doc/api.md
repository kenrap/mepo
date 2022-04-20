# Mepolang API
## bind_button
Create a UI button which executes a mepolang action

**Arguments**:
  - visible_only_when_has_pins (number): Set to 1 to only show buton *if* there are visible pins
  - button_text (text) : Text that will be shown on the button
  - mepolang_expression (text) : Mepolang expression to run on clicking the button

## bind_click
Bind a particular number of succesive clicks to run a mepolang action

**Arguments**:
  - button (number): Mousebutton to bind (1 = left, 2 = right, 3 = middle)
  - clicks (number): Number of succesive clicks to trigger action
  - mepolang_expression (text) : Mepolang expression to run

## bind_gesture
Bind a multitouch gesture event to execute a mepolang action

**Arguments**:
  - action (text) : Gesture action (set to either `pan` or `rotate`)
  - fingers (number): Number of fingers to trigger expression
  - direction (number): Direction for gesture (e.g. `1` for in or `2` for out)
  - mepolang_expression (text) : Mepolang expression to run

## bind_key
Bind a key combination to execute a mepolang action

**Arguments**:
  - modifier (text) : Modifier combination (c=control, s=shift, a=alt); ex. `cs` would mean control and shift
  - key (text) : Key to bind; note case indescriminate since modifier handled by modifier argument
  - mepolang_expression (text) : Mepolang expression to run

## bind_signal
Bind a signal to execute a mepolang action

**Arguments**:
  - signal_name (text) : Signal name; can be `USR1` or `USR2`
  - mepolang_expression (text) : Mepolang expression to run

## cache_dlbbox
Queue tiles for a bounding box to download to the cache in the background for the given zoom levels

**Arguments**:
  - a_lat (number): Starting latitude
  - a_lon (number): Starting longitude
  - b_lat (number): Ending latitude
  - b_lon (number): Ending longitude
  - zoom_min (number): Minimum zoom level
  - zoom_max (number): Maximum zoom level

## cache_dlradius
Queue tiles for a bounding box to download to the cache in the background for the given zoom levels

**Arguments**:
  - lat (number): Centerpoint latitude
  - lon (number): Centerpoint longitude
  - zoom_min (number): Minimum zoom level
  - zoom_max (number): Maximum zoom level
  - km_radius (number): Radius from centerpoint in kilometers to download tiles for

## cache_queueclear
Clear any queued background downloading process


## center_on_coords
Center the map on the given coordinate

**Arguments**:
  - lat (number): Latitude
  - lon (number): Longitude

## center_on_mouse
Center the map on the current position of the mouse


## center_on_pin
Center the map on the currently active pin


## clipcopy
Copy the current map coordinates to the clipboard; will be in format: `lat lon`


## clippaste
Extract clipboard contents and either center on coordinate (if passed `lat lon` format); otherwise run clipboard contents as mepolang


## fileload
Load mepolang from an arbitrary filesystem file

**Arguments**:
  - filepath (text) : Path to file to load

## move_relative
Move the map by a relative x/y amount

**Arguments**:
  - rel_x (number): Relative x amount
  - rel_y (number): Relative y amount

## pin_add
Add a pin to the map

**Arguments**:
  - group_number (number): Group number
  - is_structural (number): If set to `1`, will be a 'structural' pin which is useful for curved paths and similar
  - lat (number): Latitude
  - lon (number): Longitude
  - handle (text) : *Unique* handle to refer to pin; can use this handle subsequently with `pin_meta` to update pin metadata
  - name (text) : Pretty name to display for pin

## pin_cycle
Cycle the currently focused pin

**Arguments**:
  - viewport_only (number): Use `1` to only cycle between pins in viewport
  - delta (number): Delta amount (positive or negative) for number of pins to skip

## pin_deactivate
Deactivate currently active pin


## pin_delete
Delete a pin by its handle

**Arguments**:
  - pin_handle (text) : Pin's handle to delete

## pin_groupprefset_n
Set a pin group's number preference

**Arguments**:
  - group_number (number): The pin group number
  - prefrence_name (text) : Preference name
  - prefrence_value (number): Preference number value

## pin_groupprefset_t
Set a pin group's text preference

**Arguments**:
  - group_number (number): The pin group number
  - prefrence_name (text) : Preference name
  - prefrence_value (text) : Preference text value

## pin_meta
Update a pin's metadata

**Arguments**:
  - group_number (number): Group number
  - pin_handle (text) : Pin handle
  - key (text) : Metadata key to update
  - value (text) : New value for metadata key

## pin_purge
Purge all pins in the current pin group


## prefinc
Increase or decrease a preference by a given delta value

**Arguments**:
  - prefname (text) : Preference name
  - delta (number): Delta value to increment/decrement (positive or negative)

## prefset_n
Set a preference number value

**Arguments**:
  - prefname (text) : Preference name
  - prefvalue (number): Preference number value

## prefset_t
Set a preference text value

**Arguments**:
  - prefname (text) : Preference name
  - prefvalue (text) : Preference number value

## preftoggle
Toggle a boolean number preference between `1` and `0`

**Arguments**:
  - prefname (text) : Preference name

## quit
Quit the application


## shellpipe
Run a system (shell) command and pipe; STDOUT returned from command will be executed back as mepolang

**Arguments**:
  - as_async (number): Set to 1 to run asynchronously (e.g. don't wait for process to complete)
  - shell_statement (text) : Shell statement to execute

## zoom_relative
Update the map's zoom level by a relative delta

**Arguments**:
  - zoom_delta (number): Zoom level relative delta

