const std = @import("std");
const types = @import("../types.zig");

pub fn validate_args(spec: types.MepoFnSpec, args: [types.MepoFnNargs]types.MepoArg) !bool {
    _ = args;
    _ = spec;
    return true;
}
