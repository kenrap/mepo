pub const DownloadTimeoutSeconds = 5;
pub const DownloadUseragent = "mepo";
pub const DownloaderPollMs = 50;
pub const TitleUpdateFrequencyMs = 2000;
pub const InitWindowH = 950;
pub const InitWindowW = 720;
pub const InitWindowX = 0;
pub const InitWindowY = 0;
pub const Tsize = 256;
pub const DragThresholdTicks = 1000;
pub const DragThresholdDelta = 10;
pub const ClickPinMaxDelta = 40;
pub const ZoomLevelToPinFontSize = [20]u8{
    9,  9,  9,  9,  9,  9,  9,  9,  9, 9, 9, 9,
    10, 11, 12, 13, 14, 15, 16, 16,
};
// Essentially the number of textures that are allowed to be loaded to
// the GPU concurrently
pub const MaxTextures = 50;

pub const DefaultBaseConfig =
    \\ # UI Buttons;
    \\ bind_button 1 [Purge] [pin_purge];
    \\ bind_button 1 [<] [pin_cycle 0 -1; center_on_pin];
    \\ bind_button 1 [>] [pin_cycle 0 1; center_on_pin];
    \\ bind_button 0 [Menu] [shellpipe mepo_ui_central_menu.sh];
    \\ bind_button 0 [Relocate] [shellpipe mepo_ui_menu_reposition_nominatim.sh];
    \\ bind_button 0 [Nominatim] [shellpipe mepo_ui_menu_search_nominatim.sh];
    \\ bind_button 0 [Overpass] [shellpipe mepo_ui_menu_search_overpass.sh];
    \\ bind_button 0 [Download] [shellpipe mepo_ui_menu_dbg_queuedownloadnoninteractive.sh];
    \\
    \\ # Gestures;
    \\ bind_gesture pan 2 1 [zoom_relative 1];
    \\ bind_gesture pan 2 -1 [zoom_relative -1];
    \\ bind_gesture rotate 3 1 [prefinc fontsize_ui 1];
    \\ bind_gesture rotate 3 -1 [prefinc fontsize_ui -1];
    \\
    \\ # Clickbindings;
    \\ bind_click 1 -1 [shellpipe mepo_ui_central_menu.sh];
    \\ bind_click 1 2  [zoom_relative 1];
    \\ bind_click 1 3  [zoom_relative -2];
    \\ bind_click 2 1  [zoom_relative -1];
    \\
    \\ # Keybindings;
    \\ bind_key _ j [move_relative 0 10];
    \\ bind_key s j [move_relative 0 100];
    \\ bind_key _ k [move_relative 0 -10];
    \\ bind_key s k [move_relative 0 -100];
    \\ bind_key _ h [move_relative -10 0];
    \\ bind_key s h [move_relative -100 0];
    \\ bind_key _ l [move_relative 10 0];
    \\ bind_key s l [move_relative 100 0];
    \\ bind_key _ = [zoom_relative 1];
    \\ bind_key _ - [zoom_relative -1];
    \\ bind_key _ n [pin_cycle 1 1;];
    \\ bind_key s n [pin_cycle 0 1; center_on_pin;];
    \\ bind_key _ p [pin_cycle 1 -1;];
    \\ bind_key s p [pin_cycle 0 -1; center_on_pin;];
    \\ bind_key _ o [pin_deactivate];
    \\ bind_key s o [pin_purge];
    \\ bind_key _ w [cache_queueclear];
    \\ bind_key c c [quit];
    \\ bind_key _ y [clipcopy];
    \\ bind_key s y [clippaste];
    \\
    \\ # Scripts hotkeys;
    \\ bind_key _ c [shellpipe mepo_ui_central_menu.sh];
    \\ bind_key _ f [shellpipe mepo_ui_menu_bookmarks_droppin.sh];
    \\ bind_key _ g [shellpipe mepo_ui_menu_reposition_nominatim.sh];
    \\ bind_key s g [shellpipe mepo_ui_menu_search_nominatim.sh];
    \\ bind_key _ b [shellpipe mepo_ui_menu_search_overpass.sh];
    \\ bind_key s r [shellpipe mepo_ui_menu_route_overpassrelation.sh];
    \\ bind_key _ r [shellpipe mepo_ui_menu_route_graphhopper.sh];
    \\ bind_key s z [shellpipe mepo_ui_menu_pref_fontsize.sh];
    \\ bind_key _ z [shellpipe mepo_ui_menu_pref_zoom.sh];
    \\ bind_key _ u [shellpipe mepo_ui_menu_pref_url.sh];
    \\ bind_key c f [shellpipe  [DIM=h MULT=1  mepo_ui_helper_pref_pan.sh]];
    \\ bind_key c b [shellpipe  [DIM=h MULT=-1 mepo_ui_helper_pref_pan.sh]];
    \\ bind_key cs f [shellpipe [DIM=w MULT=1  mepo_ui_helper_pref_pan.sh]];
    \\ bind_key cs b [shellpipe [DIM=w MULT=-1 mepo_ui_helper_pref_pan.sh]];
    \\ bind_key _ q [shellpipe [mepo_ui_menu_dbg_queuedownloadinteractive.sh]];
    \\ bind_key s q [shellpipe [mepo_ui_menu_dbg_queuedownloadnoninteractive.sh]];
    \\ bind_key _ [1] [pin_groupprefset_n 0 active 1];
    \\ bind_key _ [2] [pin_groupprefset_n 1 active 1];
    \\ bind_key _ [3] [pin_groupprefset_n 2 active 1];
    \\ bind_key _ [4] [pin_groupprefset_n 3 active 1];
    \\ bind_key _ [5] [pin_groupprefset_n 4 active 1];
    \\ bind_key _ [6] [pin_groupprefset_n 5 active 1];
    \\ bind_key _ [7] [pin_groupprefset_n 6 active 1];
    \\ bind_key _ [8] [pin_groupprefset_n 7 active 1];
    \\ bind_key _ [9] [pin_groupprefset_n 8 active 1];
    \\ bind_key _ [0] [pin_groupprefset_n 9 active 1];
    \\ bind_key _ / [preftoggle help];
    \\ bind_key _ d [preftoggle debug_tiles];
    \\ bind_key _ e [preftoggle overlay_pindetails];
    \\ bind_key _ s [preftoggle overlay_debugbar];
    \\ bind_key _ m [preftoggle tile_cache_network];
    \\ bind_key s c [center_on_mouse];
    \\
    \\ # Signals;
    \\ bind_signal USR1 [zoom_relative 1];
    \\ bind_signal USR2 [zoom_relative -1];
    \\
    \\ # Prefs;
    \\ center_on_coords 40.78392 -73.96442;
    \\ prefset_n fontsize_ui 16;
    \\ prefset_n distance_unit_tf_km_mi 0;
    \\ prefset_n crosshair_size 15;
    \\ prefset_n debug_message_enabled 1;
    \\ prefset_n debug_stderr 0;
    \\ prefset_n debug_tiles 0;
    \\ prefset_n overlay_debugbar 1;
    \\ prefset_n overlay_pindetails 1;
    \\ prefset_n zoom 14;
    \\ prefset_n tile_cache_network 1;
    \\ prefset_n tile_cache_max_n_transfers 20;
    \\ # E.g. default 30 day expiry: 60s * 60m * 24h * 30 days;
    \\ prefset_n tile_cache_expiry_seconds 2592000;
    \\ prefset_t tile_cache_dir $XDG_CACHE_HOME/mepo/tiles;
    \\ prefset_t tile_cache_url https://tile.openstreetmap.org/%3$d/%1$d/%2$d.png;
    \\
    \\ # Pins;
    \\ pin_groupprefset_t 0 color #0000ff;
    \\ pin_groupprefset_t 1 color #116e0e;
    \\ pin_groupprefset_t 2 color #7502ab;
    \\ pin_groupprefset_t 3 color #cf0064;
    \\ pin_groupprefset_t 4 color #b89600;
    \\ pin_groupprefset_n 0 visible 1;
    \\ pin_groupprefset_n 1 visible 1;
    \\ pin_groupprefset_n 2 visible 1;
    \\ pin_groupprefset_n 3 visible 1;
    \\ pin_groupprefset_n 4 visible 1;
    \\
    \\ # User-customizable bookmarks / arbitrary mepolang file;
    \\ fileload $XDG_CONFIG_HOME/mepo/config;
;
