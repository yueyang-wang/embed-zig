const std = @import("std");

pub const StdLog = struct {
    pub fn debug(_: StdLog, msg: []const u8) void {
        std.debug.print("[debug] {s}\n", .{msg});
    }

    pub fn info(_: StdLog, msg: []const u8) void {
        std.debug.print("[info] {s}\n", .{msg});
    }

    pub fn warn(_: StdLog, msg: []const u8) void {
        std.debug.print("[warn] {s}\n", .{msg});
    }

    pub fn err(_: StdLog, msg: []const u8) void {
        std.debug.print("[error] {s}\n", .{msg});
    }
};
