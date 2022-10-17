pub const Version = "1.0";
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
    \\ bind_button 0 -1 [Menu] [shellpipe_sync mepo_ui_central_menu.sh] [];
    \\ bind_button 0 -1 [Center] [shellpipe_sync [mepo_ui_menu_user_pin_updater.sh droppinactivateandcenter]] [];
    \\ bind_button 0 -1 [Relocate] [shellpipe_sync mepo_ui_menu_reposition_nominatim.sh] [];
    \\ bind_button 0 -1 [Nm] [shellpipe_sync mepo_ui_menu_search_nominatim.sh] [];
    \\ bind_button 0 -1 [Op] [shellpipe_sync mepo_ui_menu_search_overpass.sh] [];
    \\ bind_button 0 -1 [Dl] [shellpipe_sync mepo_ui_menu_dbg_queuedownloadnoninteractive.sh] [];

    \\ bind_button 1 -1 [Purge] [pin_purge] [];
    \\ bind_button 1 -1 [Del] [pin_delete -1 []; pin_cycle 0 1; center_on_pin] [];
    \\ bind_button 1 -1 [>] [pin_cycle 0 1; center_on_pin] [];
    \\ bind_button 1 -1 [<] [pin_cycle 0 -1; center_on_pin] [];
    \\ bind_button 1 9 [9] [pin_transfer -1 [] 9] [pin_transfer -1 [all] 9];
    \\ bind_button 1 8 [8] [pin_transfer -1 [] 8] [pin_transfer -1 [all] 8];
    \\ bind_button 1 7 [7] [pin_transfer -1 [] 7] [pin_transfer -1 [all] 7];
    \\ bind_button 1 6 [6] [pin_transfer -1 [] 6] [pin_transfer -1 [all] 6];
    \\ bind_button 1 5 [5] [pin_transfer -1 [] 5] [pin_transfer -1 [all] 5];
    \\ bind_button 1 4 [4] [pin_transfer -1 [] 4] [pin_transfer -1 [all] 4];
    \\ bind_button 1 3 [3] [pin_transfer -1 [] 3] [pin_transfer -1 [all] 3];
    \\ bind_button 1 2 [2] [pin_transfer -1 [] 2] [pin_transfer -1 [all] 2];
    \\ bind_button 1 1 [1] [pin_transfer -1 [] 1] [pin_transfer -1 [all] 1];
    \\ bind_button 1 0 [0] [pin_transfer -1 [] 0] [pin_transfer -1 [all] 0];
    \\
    \\ # Gestures;
    \\ bind_gesture pan 2 1 [zoom_relative 1];
    \\ bind_gesture pan 2 -1 [zoom_relative -1];
    \\ bind_gesture rotate 3 1 [prefinc fontsize_ui 1];
    \\ bind_gesture rotate 3 -1 [prefinc fontsize_ui -1];
    \\
    \\ # Clickbindings;
    \\ bind_click 1 -1 [shellpipe_sync mepo_ui_central_menu.sh];
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
    \\ bind_key c s [filedump rp $XDG_CACHE_HOME/mepo/savestate];
    \\ bind_key cs s [fileload $XDG_CACHE_HOME/mepo/savestate];
    \\
    \\ # Timers;
    \\ bind_timer 20 [shellpipe_async 1 [mepo_ui_menu_user_pin_updater.sh droppin]];
    \\ shellpipe_async 1 [mepo_ui_menu_user_pin_updater.sh droppin];
    \\
    \\ # Scripts hotkeys;
    \\ bind_key _ c [shellpipe_sync mepo_ui_central_menu.sh];
    \\ bind_key _ f [shellpipe_async 0 mepo_ui_menu_pin_editor.sh];
    \\ bind_key _ g [shellpipe_sync mepo_ui_menu_reposition_nominatim.sh];
    \\ bind_key s g [shellpipe_sync mepo_ui_menu_search_nominatim.sh];
    \\ bind_key _ b [shellpipe_sync mepo_ui_menu_search_overpass.sh];
    \\ bind_key s r [shellpipe_sync mepo_ui_menu_route_overpassrelation.sh];
    \\ bind_key _ r [shellpipe_sync mepo_ui_menu_route_graphhopper.sh];
    \\ bind_key s z [shellpipe_sync mepo_ui_menu_pref_fontsize.sh];
    \\ bind_key _ z [shellpipe_sync mepo_ui_menu_pref_zoom.sh];
    \\ bind_key _ u [shellpipe_sync mepo_ui_menu_pref_url.sh];
    \\ bind_key c f [shellpipe_sync  [DIM=h MULT=1  mepo_ui_helper_pref_pan.sh]];
    \\ bind_key c b [shellpipe_sync  [DIM=h MULT=-1 mepo_ui_helper_pref_pan.sh]];
    \\ bind_key cs f [shellpipe_sync [DIM=w MULT=1  mepo_ui_helper_pref_pan.sh]];
    \\ bind_key cs b [shellpipe_sync [DIM=w MULT=-1 mepo_ui_helper_pref_pan.sh]];
    \\ bind_key _ q [shellpipe_sync [mepo_ui_menu_dbg_queuedownloadinteractive.sh]];
    \\ bind_key s q [shellpipe_sync [mepo_ui_menu_dbg_queuedownloadnoninteractive.sh]];
    \\ bind_key _ x [shellpipe_sync [mepo_ui_menu_user_pin_updater.sh droppinactivateandcenter]];

    \\ bind_key _ [1] [pin_groupactivate 0];
    \\ bind_key _ [2] [pin_groupactivate 1];
    \\ bind_key _ [3] [pin_groupactivate 2];
    \\ bind_key _ [4] [pin_groupactivate 3];
    \\ bind_key _ [5] [pin_groupactivate 4];
    \\ bind_key _ [6] [pin_groupactivate 5];
    \\ bind_key _ [7] [pin_groupactivate 6];
    \\ bind_key _ [8] [pin_groupactivate 7];
    \\ bind_key _ [9] [pin_groupactivate 8];
    \\ bind_key _ [0] [pin_groupactivate 9];
    \\ bind_key _ / [preftoggle help];
    \\ bind_key _ e [preftoggle overlay_pindetails];
    \\ bind_key _ s [preftoggle overlay_debugbar];
    \\ bind_key _ m [preftoggle tile_cache_network];
    \\ bind_key s c [center_on_mouse];
    \\
    \\ # Signals;
    \\ bind_signal USR1 [zoom_relative 1];
    \\ bind_signal USR2 [zoom_relative -1];
    \\ bind_signal TERM [quit];
    \\ bind_signal INT  [quit];
    \\
    \\ # Quit action;
    \\ bind_quit [filedump rp $XDG_CACHE_HOME/mepo/savestate];
    \\
    \\ # Prefs;
    \\ prefset_n lat 40.78392;
    \\ prefset_n lon -73.96442;
    \\ prefset_n fontsize_ui 16;
    \\ prefset_n distance_unit_tf_km_mi 1;
    \\ prefset_n crosshair_size 15;
    \\ prefset_n debug_message_enabled 1;
    \\ prefset_n debug_stderr 0;
    \\ prefset_n overlay_debugbar 1;
    \\ prefset_n overlay_pindetails 1;
    \\ prefset_n zoom 14;
    \\ prefset_n tile_cache_network 1;
    \\ prefset_n tile_cache_max_n_transfers 20;
    \\ # E.g. default 30 day expiry: 60s * 60m * 24h * 30 days;
    \\ prefset_n tile_cache_expiry_seconds 2592000;
    \\ prefset_t tile_cache_dir $XDG_CACHE_HOME/mepo/tiles;
    \\ prefset_t tile_cache_url https://tile.openstreetmap.org/%3$d/%1$d/%2$d.png;
    \\ prefset_t pingroup_0_color #0000ff;
    \\ prefset_t pingroup_1_color #116e0e;
    \\ prefset_t pingroup_2_color #7502ab;
    \\ prefset_t pingroup_3_color #cf0064;
    \\ prefset_t pingroup_4_color #b89600;
    \\ prefset_t pingroup_5_color #b8f3ff;
    \\ prefset_t pingroup_6_color #fff673;
    \\ prefset_t pingroup_7_color #004a0c;
    \\ prefset_t pingroup_8_color #fdcfff;
    \\ prefset_t pingroup_9_color #ff8308;

    \\ prefset_n pingroup_0_ordered 0;
    \\ prefset_n pingroup_1_ordered 0;
    \\ prefset_n pingroup_2_ordered 0;
    \\ prefset_n pingroup_3_ordered 0;
    \\ prefset_n pingroup_4_ordered 0;
    \\ prefset_n pingroup_5_ordered 0;
    \\ prefset_n pingroup_6_ordered 0;
    \\ prefset_n pingroup_7_ordered 1;
    \\ prefset_n pingroup_8_ordered 1;
    \\ prefset_n pingroup_9_ordered 1;
    \\ 
    \\ # User-customizable bookmarks / arbitrary mepolang file;
    \\ fileload $XDG_CACHE_HOME/mepo/savestate;
    \\ fileload $XDG_CONFIG_HOME/mepo/config;
    \\ fileload $XDG_CONFIG_HOME/mepo/bookmarks;
;
