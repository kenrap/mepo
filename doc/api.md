# Mepolang API
## **bind_button**
Create a UI button which executes a mepolang action

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| visible_only_when_has_pins | Number | Set to 1 to only show buton *if* there are visible pins |
| button_text | Text   | Text that will be shown on the button |
| mepolang_expression | Text   | Mepolang expression to run on clicking the button |

## **bind_click**
Bind a particular number of succesive clicks to run a mepolang action

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| button | Number | Mousebutton to bind (1 = left, 2 = right, 3 = middle) |
| clicks | Number | Number of succesive clicks to trigger action |
| mepolang_expression | Text   | Mepolang expression to run |

## **bind_gesture**
Bind a multitouch gesture event to execute a mepolang action

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| action | Text   | Gesture action (set to either `pan` or `rotate`) |
| fingers | Number | Number of fingers to trigger expression |
| direction | Number | Direction for gesture (e.g. `1` for in or `2` for out) |
| mepolang_expression | Text   | Mepolang expression to run |

## **bind_key**
Bind a key combination to execute a mepolang action

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| modifier | Text   | Modifier combination (c=control, s=shift, a=alt); ex. `cs` would mean control and shift |
| key | Text   | Key to bind; note case indescriminate since modifier handled by modifier argument |
| mepolang_expression | Text   | Mepolang expression to run |

## **bind_signal**
Bind a signal to execute a mepolang action

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| signal_name | Text   | Signal name; can be `USR1` or `USR2` |
| mepolang_expression | Text   | Mepolang expression to run |

## **cache_dlbbox**
Queue tiles for a bounding box to download to the cache in the background for the given zoom levels

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| a_lat | Number | Starting latitude |
| a_lon | Number | Starting longitude |
| b_lat | Number | Ending latitude |
| b_lon | Number | Ending longitude |
| zoom_min | Number | Minimum zoom level |
| zoom_max | Number | Maximum zoom level |

## **cache_dlradius**
Queue tiles for a bounding box to download to the cache in the background for the given zoom levels

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| lat | Number | Centerpoint latitude |
| lon | Number | Centerpoint longitude |
| zoom_min | Number | Minimum zoom level |
| zoom_max | Number | Maximum zoom level |
| km_radius | Number | Radius from centerpoint in kilometers to download tiles for |

## **cache_queueclear**
Clear any queued background downloading process

## **center_on_mouse**
Center the map on the current position of the mouse


## **center_on_pin**
Center the map on the currently active pin


## **clipcopy**
Copy the current map coordinates to the clipboard; will be in format: `lat lon`


## **clippaste**
Extract clipboard contents and either center on coordinate (if passed `lat lon` format); otherwise run clipboard contents as mepolang


## **fileload**
Load mepolang from an arbitrary filesystem file

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| filepath | Text   | Path to file to load |

## **move_relative**
Move the map by a relative x/y amount

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| rel_x | Number | Relative x amount |
| rel_y | Number | Relative y amount |

## **pin_add**
Add a pin to the map

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| group_number | Number | Group number |
| is_structural | Number | If set to `1`, will be a 'structural' pin which is useful for curved paths and similar |
| lat | Number | Latitude |
| lon | Number | Longitude |
| handle | Text   | *Unique* handle to refer to pin; can use this handle subsequently with `pin_meta` to update pin metadata |
| name | Text   | Pretty name to display for pin |

## **pin_cycle**
Cycle the currently focused pin

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| viewport_only | Number | Use `1` to only cycle between pins in viewport |
| delta | Number | Delta amount (positive or negative) for number of pins to skip |

## **pin_deactivate**
Deactivate currently active pin


## **pin_delete**
Delete a pin by its handle

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| pin_handle | Text   | Pin's handle to delete |

## **pin_groupprefset_n**
Set a pin group's number preference

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| group_number | Number | The pin group number |
| prefrence_name | Text   | Preference name |
| prefrence_value | Number | Preference number value |

## **pin_groupprefset_t**
Set a pin group's text preference

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| group_number | Number | The pin group number |
| prefrence_name | Text   | Preference name |
| prefrence_value | Text   | Preference text value |

## **pin_meta**
Update a pin's metadata

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| group_number | Number | Group number |
| pin_handle | Text   | Pin handle |
| key | Text   | Metadata key to update |
| value | Text   | New value for metadata key |

## **pin_purge**
Purge all pins in the current pin group


## **prefinc**
Increase or decrease a preference by a given delta value

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| prefname | Text   | Preference name |
| delta | Number | Delta value to increment/decrement (positive or negative) |

## **prefset_n**
Set a preference number value

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| prefname | Text   | Preference name |
| prefvalue | Number | Preference number value |

## **prefset_t**
Set a preference text value

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| prefname | Text   | Preference name |
| prefvalue | Text   | Preference number value |

## **preftoggle**
Toggle a boolean number preference between `1` and `0`

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| prefname | Text   | Preference name |

## **quit**
Quit the application


## **shellpipe**
Run a system (shell) command and pipe; STDOUT returned from command will be executed back as mepolang

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| as_async | Number | Set to 1 to run asynchronously (e.g. don't wait for process to complete) |
| shell_statement | Text   | Shell statement to execute |

## **zoom_relative**
Update the map's zoom level by a relative delta

**Arguments**:

| **Name** | **Datatype** | **Description** |
| -------- | ------------ | --------------- |
| zoom_delta | Number | Zoom level relative delta |

