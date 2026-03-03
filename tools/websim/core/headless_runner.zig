const std = @import("std");
const engine_mod = @import("engine.zig");
const protocol = @import("protocol.zig");
const yaml_case = @import("yaml_case.zig");

pub const RunnerError = error{
    MissingOutbound,
    MismatchOutbound,
    UnexpectedOutboundRemaining,
    NoYamlFiles,
};

pub const RunSummary = struct {
    files: usize,
    steps: usize,
};

pub fn runFile(allocator: std.mem.Allocator, file_path: []const u8) !RunSummary {
    var case_file = try yaml_case.loadFromFile(allocator, file_path);
    defer case_file.deinit();

    var engine = try engine_mod.Engine.init(allocator);
    defer engine.deinit();

    var step_count: usize = 0;

    for (case_file.steps) |step| {
        step_count += 1;

        switch (step.kind) {
            .send => {
                try engine.applySend(step.message);
            },
            .expect => {
                const actual = engine.popOutbound() orelse {
                    std.debug.print("[websim:test] missing outbound at {s}:{}\n", .{ file_path, step.line_no });
                    return error.MissingOutbound;
                };

                if (!protocol.messageMatches(step.message, actual)) {
                    std.debug.print("[websim:test] outbound mismatch at {s}:{}\n", .{ file_path, step.line_no });

                    var expected_buf: [512]u8 = undefined;
                    var actual_buf: [512]u8 = undefined;
                    var expected_fbs = std.io.fixedBufferStream(&expected_buf);
                    var actual_fbs = std.io.fixedBufferStream(&actual_buf);
                    protocol.formatMessage(step.message, expected_fbs.writer()) catch {};
                    protocol.formatMessage(actual, actual_fbs.writer()) catch {};

                    std.debug.print("  expected: {s}\n", .{expected_fbs.getWritten()});
                    std.debug.print("  actual  : {s}\n", .{actual_fbs.getWritten()});

                    return error.MismatchOutbound;
                }
            },
        }
    }

    if (engine.hasPendingOutbound()) {
        std.debug.print("[websim:test] unexpected pending outbound count={} in {s}\n", .{ engine.pendingOutboundCount(), file_path });
        return error.UnexpectedOutboundRemaining;
    }

    return .{ .files = 1, .steps = step_count };
}

pub fn runDir(allocator: std.mem.Allocator, dir_path: []const u8) !RunSummary {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var names = std.ArrayList([]const u8).empty;
    defer {
        for (names.items) |name| {
            allocator.free(name);
        }
        names.deinit(allocator);
    }

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".yaml")) continue;
        try names.append(allocator, try allocator.dupe(u8, entry.name));
    }

    if (names.items.len == 0) return error.NoYamlFiles;

    std.sort.heap([]const u8, names.items, {}, lessThanFileName);

    var total_files: usize = 0;
    var total_steps: usize = 0;

    for (names.items) |name| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, name });
        defer allocator.free(full_path);

        const summary = try runFile(allocator, full_path);
        total_files += summary.files;
        total_steps += summary.steps;
    }

    return .{ .files = total_files, .steps = total_steps };
}

fn lessThanFileName(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.lessThan(u8, lhs, rhs);
}
