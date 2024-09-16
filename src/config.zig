pub const Version = "1.3.3";
pub const DownloadTimeoutSeconds = 5;
pub const DownloadUseragent = "mepo";
pub const DownloaderPollMs = 50;
pub const TitleUpdateFrequencyMs = 2000;
pub const InitWindowH = 950;
pub const InitWindowW = 720;
pub const Tsize = 256;
pub const DragThresholdTicks = 1000;
pub const DragThresholdDelta = 10;
pub const ClickPinMaxDelta = 40;
pub const ZoomLevelToPinFontSize = [20]u8{
    9,  9,  9,  9,  9,  9,  9,  9,  9, 9, 9, 9,
    10, 11, 12, 13, 14, 15, 16, 16,
};
// Number of textures (in both pin & OSM tile cache) loaded to GPU concurrently
// can be modified with boot CLI param -tx, e.g. -tx400 for 400 textures
pub var MaxTextures: usize = 200;
pub const DefaultBaseConfig = @embedFile("config.json");
