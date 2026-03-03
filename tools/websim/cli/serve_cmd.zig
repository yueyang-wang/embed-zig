const std = @import("std");
const host = @import("../webui/host.zig");

pub const CliError = error{
    InvalidArguments,
    MissingValue,
};

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var options = host.Options{};

    var i: usize = 0;
    while (i < args.len) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--style")) {
            if (i + 1 >= args.len) return error.MissingValue;
            options.style_dir = args[i + 1];
            i += 2;
            continue;
        }

        if (std.mem.eql(u8, arg, "--port")) {
            if (i + 1 >= args.len) return error.MissingValue;
            options.port = std.fmt.parseInt(u16, args[i + 1], 10) catch return error.InvalidArguments;
            i += 2;
            continue;
        }

        return error.InvalidArguments;
    }

    try host.run(allocator, options);
}

test "serve cmd rejects unknown argument" {
    try std.testing.expectError(error.InvalidArguments, run(std.testing.allocator, &[_][]const u8{"--unknown"}));
}
