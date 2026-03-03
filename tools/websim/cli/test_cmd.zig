const std = @import("std");
const runner = @import("../core/headless_runner.zig");

pub const CliError = error{
    InvalidArguments,
};

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len != 2) {
        printUsage();
        return error.InvalidArguments;
    }

    if (std.mem.eql(u8, args[0], "-f")) {
        const summary = try runner.runFile(allocator, args[1]);
        std.debug.print("[websim:test] ok file={s} steps={}\n", .{ args[1], summary.steps });
        return;
    }

    if (std.mem.eql(u8, args[0], "-d")) {
        const summary = try runner.runDir(allocator, args[1]);
        std.debug.print("[websim:test] ok dir={s} files={} steps={}\n", .{ args[1], summary.files, summary.steps });
        return;
    }

    printUsage();
    return error.InvalidArguments;
}

fn printUsage() void {
    std.debug.print(
        "usage:\n  websim test -f <yaml_file>\n  websim test -d <yaml_dir>\n",
        .{},
    );
}

test "invalid args rejected" {
    try std.testing.expectError(error.InvalidArguments, run(std.testing.allocator, &[_][]const u8{}));
    try std.testing.expectError(error.InvalidArguments, run(std.testing.allocator, &[_][]const u8{ "-x", "foo" }));
}
