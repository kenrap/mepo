pub const DownloadTimeoutSeconds = 5;
pub const DownloadUseragent = "mepo";
pub const DownloaderPollMs = 50;
pub const FontSize = 14;
pub const InitWindowH = 950;
pub const InitWindowW = 720;
pub const InitWindowX = 0;
pub const InitWindowY = 0;
pub const Tsize = 256;
pub const ClickTimeoutMs = 200;

pub const DefaultBaseConfig =
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
    \\ bind_key _ n [pin_cycle 1 0];
    \\ bind_key s n [pin_cycle 1 1];
    \\ bind_key _ o [pin_deactivate];
    \\ bind_key _ p [pin_purge];
    \\
    \\ bind_key c c [quit];
    \\ 
    \\ bind_key _ g [shellpipe [mepo_script_nominatim.sh searchworldpickandgo]];
    \\ bind_key s g [shellpipe [mepo_script_nominatim.sh searchbboxandpindrops]];
    \\ bind_key _ b [shellpipe [mepo_script_overpass.sh]];
    \\ bind_key _ z [shellpipe mepo_script_zoomlevelset.sh];
    \\ bind_key _ s [shellpipe mepo_script_relationloader.sh];
    \\ bind_key _ q [shellpipe [mepo_script_queuedownload.sh interactive]];
    \\ bind_key s q [shellpipe [mepo_script_queuedownload.sh noninteractive]];
    \\ bind_key cs q [cache_queueclear];
    \\ bind_key s q [shellpipe [mepo_script_queuedownload.sh noninteractive]];
    \\ bind_key _ u [shellpipe mepo_script_urlsourceset.sh];
    \\ bind_key _ a [shellpipe mepo_script_apilangexec.sh];
    \\ bind_key c f [shellpipe [mepo_script_panscreen.sh h 1]];
    \\ bind_key c b [shellpipe [mepo_script_panscreen.sh h -1]];
    \\ bind_key cs f [shellpipe [mepo_script_panscreen.sh w 1]];
    \\ bind_key cs b [shellpipe [mepo_script_panscreen.sh w -1]];
    \\
    \\ bind_key _ / [preftoggle help];
    \\ bind_key _ d [preftoggle debug_tiles];
    \\ bind_key _ e [preftoggle debug_vars];
    \\ bind_key _ r [preftoggle download_bar];
    \\ bind_key _ m [preftoggle tile_cache_network];
    \\ bind_key _ c [center_on_mouse];
    \\
    \\ bind_signal USR1 [zoom_relative 1];
    \\ bind_signal USR2 [zoom_relative -1];
    \\
    \\ center_on_coords 40.78392 -73.96442;
    \\ prefset distance_unit_tf_km_mi 0;
    \\ prefset crosshair_on 1;
    \\ prefset crosshair_size 15;
    \\ prefset debug_message_enabled 1;
    \\ prefset debug_stderr 1;
    \\ prefset debug_tiles 0;
    \\ prefset debug_vars 1;
    \\ prefset download_bar 1;
    \\ prefset zoom 14;
    \\ prefset tile_cache_network 1;
    \\ prefset tile_cache_max_n_transfers 20;
    \\ prefset tile_cache_dir ~/.cache/mepo/tiles;
    \\ prefset tile_cache_url https://tile.openstreetmap.org/%3$d/%1$d/%2$d.png;
    // E.g. default 30 day expiry: 60s * 60m * 24h * 30 days
    \\ prefset tile_cache_expiry_seconds 2592000;
    \\
    \\ pin_add 40.7418 -73.9899 baz;
    \\
    \\ fileload ~/.mepo/bookmarks;
;
