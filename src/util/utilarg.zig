const std = @import("std");
const types = @import("../types.zig");

pub fn validate_args(spec: types.MepoFnSpec, args: [types.MepoFnNargs]types.MepoArg) !bool {
    for (spec.args) |expect_spec_arg, expect_spec_arg_i| {
        switch (expect_spec_arg) {
            .Number => {
                switch (args[expect_spec_arg_i]) {
                    .Text => return error.ExpectNumberGotText,
                    .Number => continue,
                }
            },
            .Text => {
                switch (args[expect_spec_arg_i]) {
                    .Number => return error.ExpectTextGotNumber,
                    .Text => continue,
                }
            },
        }
    }
    return true;
}
