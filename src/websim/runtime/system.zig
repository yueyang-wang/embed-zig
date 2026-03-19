const std = @import("std");
const embed = @import("../../mod.zig");

pub const System = struct {
    pub fn getCpuCount(_: *const System) embed.runtime.system.Error!usize {
        return std.Thread.getCpuCount() catch embed.runtime.system.Error.QueryFailed;
    }
};
