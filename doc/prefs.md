# Mepolang Preferences (0.5)

| **Name** | **Description** | **Datatype** | **Min** | **Max** | **Default Value** |
| -------- | --------------- | ------------ | ------- | ------- | ----------------- |
| lat | Latitude of the map | Float      | ªªª | ªª | 40.78392 |
| lon | Longitude of the map | Float      | ªªªª | ªªª | -73.96442 |
| zoom | Zoom level of the map (should be set between 0-19) | Uint8      | ª | ªª | 14 |
| debug_message_enabled | Whether debug overlay message should be shown in the UI | Bool (0/1) |  |  | true |
| distance_unit_tf_km_mi | Whether to show distance in km (true) or mi (false) | Bool (0/1) |  |  | false |
| overlay_debugbar | Whether to show the debug bar | Bool (0/1) |  |  | true |
| help | Whether to show the help overlay | Bool (0/1) |  |  | false |
| overlay_pindetails | Whether to show the pin detail overlay | Bool (0/1) |  |  | true |
| crosshair_size | Pixel size of the crosshairs | Uint8      | ª | ªªª | 15 |
| drag_scale | Scale for dragging | Uint8      | ª | ªªª | 2 |
| fontsize_ui | Size of the font in the UI | Uint8      | ª | ªªª | 20 |
| debug_stderr | Send debug information to STDERR | Bool (0/1) |  |  | false |
| tile_cache_max_n_transfers | Maximum number of concurrent transfers for curl | Uint8      | ª | ªªªª | 20 |
| tile_cache_expiry_seconds | Number of seconds before a downloaded tiledata should be considered invalid | Float      | ªª | ªªªªªªªª | -1 |
| tile_cache_network | Whether to donwload new tiledata from external servers; if 0 that means you're offline | Bool (0/1) |  |  | true |
| tile_cache_dir | Path of directory to store the downloaded tiles | Text       |  |  | null |
| tile_cache_url | URL source for the tiles, uses %1/%2/%3 to represent X/Y/Z | Text       |  |  | null |
| pingroup_0_ordered | Whether pingroup 0 should be ordered | Bool (0/1) |  |  | false |
| pingroup_1_ordered | Whether pingroup 1 should be ordered | Bool (0/1) |  |  | false |
| pingroup_2_ordered | Whether pingroup 2 should be ordered | Bool (0/1) |  |  | false |
| pingroup_3_ordered | Whether pingroup 3 should be ordered | Bool (0/1) |  |  | false |
| pingroup_4_ordered | Whether pingroup 4 should be ordered | Bool (0/1) |  |  | false |
| pingroup_5_ordered | Whether pingroup 5 should be ordered | Bool (0/1) |  |  | false |
| pingroup_6_ordered | Whether pingroup 6 should be ordered | Bool (0/1) |  |  | false |
| pingroup_7_ordered | Whether pingroup 7 should be ordered | Bool (0/1) |  |  | false |
| pingroup_8_ordered | Whether pingroup 8 should be ordered | Bool (0/1) |  |  | false |
| pingroup_9_ordered | Whether pingroup 9 should be ordered | Bool (0/1) |  |  | false |
| pingroup_0_color | Color to indicate pingroup 0 | Uint24     |  |  | 0 |
| pingroup_1_color | Color to indicate pingroup 1 | Uint24     |  |  | 0 |
| pingroup_2_color | Color to indicate pingroup 2 | Uint24     |  |  | 0 |
| pingroup_3_color | Color to indicate pingroup 3 | Uint24     |  |  | 0 |
| pingroup_4_color | Color to indicate pingroup 4 | Uint24     |  |  | 0 |
| pingroup_5_color | Color to indicate pingroup 5 | Uint24     |  |  | 0 |
| pingroup_6_color | Color to indicate pingroup 6 | Uint24     |  |  | 0 |
| pingroup_7_color | Color to indicate pingroup 7 | Uint24     |  |  | 0 |
| pingroup_8_color | Color to indicate pingroup 8 | Uint24     |  |  | 0 |
| pingroup_9_color | Color to indicate pingroup 9 | Uint24     |  |  | 0 |
