# Mepolang Preferences (0.5)

Internally mepo keeps track of a number of preferences which control all
state for the application. These preferences can all be set with the commands
`preset_n` for numerical prerefences and `prefset_t` for textual preferences.
You can also use `filedump` to examine the current values of all preferences.

Below is an exhaustive list of all available preferences:

| **Name** | **Description** | **Datatype** | **Min** | **Max** | **Default Value** |
| -------- | --------------- | ------------ | ------- | ------- | ----------------- |
| lat | Latitude of the map | Number (float) | -90 | 90 | 40.78392 |
| lon | Longitude of the map | Number (float) | -180 | 180 | -73.96442 |
| zoom | Zoom level of the map (should be set between 0-19) | Number (u8) | 0 | 19 | 14 |
| debug_message_enabled | Whether debug overlay message should be shown in the UI | Number (bool) |  |  | 1 |
| distance_unit_tf_km_mi | Whether to show distance in km (true) or mi (false) | Number (bool) |  |  | 0 |
| overlay_debugbar | Whether to show the debug bar | Number (bool) |  |  | 1 |
| help | Whether to show the help overlay | Number (bool) |  |  | 0 |
| overlay_pindetails | Whether to show the pin detail overlay | Number (bool) |  |  | 1 |
| crosshair_size | Pixel size of the crosshairs | Number (u8) | 0 | 300 | 15 |
| drag_scale | Scale for dragging | Number (u8) | 1 | 200 | 2 |
| fontsize_ui | Size of the font in the UI | Number (u8) | 1 | 200 | 20 |
| debug_stderr | Send debug information to STDERR | Number (bool) |  |  | 0 |
| tile_cache_max_n_transfers | Maximum number of concurrent transfers for curl | Number (u8) | 1 | 9999 | 20 |
| tile_cache_expiry_seconds | Number of seconds before a downloaded tiledata should be considered invalid | Number (float) | -1 | 99999999 | -1 |
| tile_cache_network | Whether to donwload new tiledata from external servers; if 0 that means you're offline | Number (bool) |  |  | 1 |
| tile_cache_dir | Path of directory to store the downloaded tiles | Text |  |  | null |
| tile_cache_url | URL source for the tiles, uses %1/%2/%3 to represent X/Y/Z | Text |  |  | null |
| pingroup_0_ordered | Whether pingroup 0 should be ordered | Number (bool) |  |  | 0 |
| pingroup_1_ordered | Whether pingroup 1 should be ordered | Number (bool) |  |  | 0 |
| pingroup_2_ordered | Whether pingroup 2 should be ordered | Number (bool) |  |  | 0 |
| pingroup_3_ordered | Whether pingroup 3 should be ordered | Number (bool) |  |  | 0 |
| pingroup_4_ordered | Whether pingroup 4 should be ordered | Number (bool) |  |  | 0 |
| pingroup_5_ordered | Whether pingroup 5 should be ordered | Number (bool) |  |  | 0 |
| pingroup_6_ordered | Whether pingroup 6 should be ordered | Number (bool) |  |  | 0 |
| pingroup_7_ordered | Whether pingroup 7 should be ordered | Number (bool) |  |  | 0 |
| pingroup_8_ordered | Whether pingroup 8 should be ordered | Number (bool) |  |  | 0 |
| pingroup_9_ordered | Whether pingroup 9 should be ordered | Number (bool) |  |  | 0 |
| pingroup_0_color | Color to indicate pingroup 0 | Number (u24) |  |  | 0 |
| pingroup_1_color | Color to indicate pingroup 1 | Number (u24) |  |  | 0 |
| pingroup_2_color | Color to indicate pingroup 2 | Number (u24) |  |  | 0 |
| pingroup_3_color | Color to indicate pingroup 3 | Number (u24) |  |  | 0 |
| pingroup_4_color | Color to indicate pingroup 4 | Number (u24) |  |  | 0 |
| pingroup_5_color | Color to indicate pingroup 5 | Number (u24) |  |  | 0 |
| pingroup_6_color | Color to indicate pingroup 6 | Number (u24) |  |  | 0 |
| pingroup_7_color | Color to indicate pingroup 7 | Number (u24) |  |  | 0 |
| pingroup_8_color | Color to indicate pingroup 8 | Number (u24) |  |  | 0 |
| pingroup_9_color | Color to indicate pingroup 9 | Number (u24) |  |  | 0 |
