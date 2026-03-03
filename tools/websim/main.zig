const std = @import("std");
const serve_cmd = @import("cli/serve_cmd.zig");
const test_cmd = @import("cli/test_cmd.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return error.InvalidArguments;
    }

    const subcommand = args[1];
    if (std.mem.eql(u8, subcommand, "test")) {
        try test_cmd.run(allocator, args[2..]);
        return;
    }

    if (std.mem.eql(u8, subcommand, "serve")) {
        try serve_cmd.run(allocator, args[2..]);
        return;
    }

    printUsage();
    return error.InvalidArguments;
}

fn printUsage() void {
    std.debug.print(
        "websim command\n\nsubcommands:\n  test -f <yaml_file>\n  test -d <yaml_dir>\n  serve [--port <port>] [--style <style_dir>]\n",
        .{},
    );
}

test "main compiles with test command module" {
    try std.testing.expect(true);
}
