const Mepo = @import("../Mepo.zig");
const types = @import("../types.zig");
const std = @import("std");
const conversionutil = @import("../util/conversionutil.zig");
const center_on_coords = @import("./center_on_coords.zig");

pub fn f_pin_add(mepo: *Mepo, args: [types.MepoFnNargs]types.MepoArg) !void {
    const lat = args[0].Number;
    const lon = args[1].Number;
    const name = args[2].Text;
    try pin_add(mepo, lat, lon, name);
}

fn pin_add(mepo: *Mepo, lat: f64, lon: f64, name: []const u8) !void {
    try mepo.pin_table.put(name, .{ .lat = lat, .lon = lon, .name = name });
}
