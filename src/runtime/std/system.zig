const std = @import("std");
const runtime = @import("../runtime.zig");

pub const StdSystem = struct {
    pub fn getCpuCount(_: StdSystem) runtime.system.Error!usize {
        return std.Thread.getCpuCount() catch runtime.system.Error.QueryFailed;
    }
};
