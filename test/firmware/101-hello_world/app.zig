//! 101-hello_world firmware application.
//!
//! Minimal firmware that logs a greeting via the board's runtime primitives.

const board_spec = @import("board_spec.zig");

pub fn run(comptime hw: type, env: anytype) void {
    _ = env;

    const Board = board_spec.Board(hw);
    const log: Board.log = .{};
    const time: Board.time = .{};

    hw.init() catch {
        log.err("hw init failed");
        return;
    };
    defer hw.deinit();

    log.info("hello from 101-hello_world");
    time.sleepMs(1000);
    log.info("done");
}

const std = @import("std");

test "run with mock hw" {
    const mock_hw = struct {
        pub const name: []const u8 = "mock_board";

        pub fn init() !void {}
        pub fn deinit() void {}

        pub const rtc_spec = struct {
            pub const Driver = struct {
                pub fn init() !@This() {
                    return .{};
                }
                pub fn deinit(_: *@This()) void {}
                pub fn uptime(_: *@This()) u64 {
                    return 0;
                }
                pub fn nowMs(_: *@This()) ?i64 {
                    return null;
                }
            };
            pub const meta = .{ .id = "rtc.mock" };
        };

        pub const log = struct {
            pub fn debug(_: @This(), _: []const u8) void {}
            pub fn info(_: @This(), _: []const u8) void {}
            pub fn warn(_: @This(), _: []const u8) void {}
            pub fn err(_: @This(), _: []const u8) void {}
        };

        pub const time = struct {
            pub fn nowMs(_: @This()) u64 {
                return 0;
            }
            pub fn sleepMs(_: @This(), _: u32) void {}
        };
    };

    run(mock_hw, .{});
}
