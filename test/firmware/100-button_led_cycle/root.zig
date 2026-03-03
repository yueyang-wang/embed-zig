const std = @import("std");

const app_mod = @import("app.zig");
const env = @import("env.zig");
const runtime_spec = @import("runtime_spec.zig");

pub const App = app_mod.App;
pub const Config = app_mod.Config;
pub const InputAction = app_mod.InputAction;
pub const LedState = app_mod.LedState;
pub const spec = runtime_spec;

/// 固件唯一入口：调用方只需要传入 runtime 与 board。
///
/// 生命周期约束：
/// - run 开始时：`runtime.init()`、`board.init()`
/// - run 退出时：`board.deinit()`、`runtime.deinit()`
pub fn run(runtime: anytype, board: anytype) !void {
    const RuntimePtr = @TypeOf(runtime);
    const BoardPtr = @TypeOf(board);

    comptime {
        if (@typeInfo(RuntimePtr) != .pointer) {
            @compileError("firmware.run(runtime, board): runtime must be pointer type");
        }
        if (@typeInfo(BoardPtr) != .pointer) {
            @compileError("firmware.run(runtime, board): board must be pointer type");
        }

        const RuntimeType = @typeInfo(RuntimePtr).pointer.child;
        const BoardType = @typeInfo(BoardPtr).pointer.child;

        _ = @TypeOf(&RuntimeType.init);
        _ = @as(*const fn (*RuntimeType) void, &RuntimeType.deinit);
        _ = @TypeOf(&BoardType.init);
        _ = @as(*const fn (*BoardType) void, &BoardType.deinit);
        _ = @as(*const fn (*BoardType) ?BoardType.Event, &BoardType.nextEvent);
    }

    try runtime.init();
    defer runtime.deinit();

    try board.init();
    defer board.deinit();

    var app = app_mod.App.init();
    const cfg = app_mod.Config{
        .long_press_ms = runtime_spec.timing.long_press_ms,
        .double_click_window_ms = runtime_spec.timing.double_click_window_ms,
    };

    while (board.nextEvent()) |event| {
        try env.processEvent(&app, cfg, board, event);
    }
}

test "firmware run performs init/deinit and processes events" {
    const Runtime = struct {
        inited: bool = false,
        deinited: bool = false,

        pub fn init(self: *@This()) !void {
            self.inited = true;
        }

        pub fn deinit(self: *@This()) void {
            self.deinited = true;
        }
    };

    const Board = struct {
        pub const Event = struct {
            op: []const u8,
            t: u64,
            dev: []const u8,
            v: struct {
                action: []const u8,
            },
        };

        pub const LedDevice = struct {
            on: bool = false,
            r: u8 = 0,
            g: u8 = 0,
            b: u8 = 0,

            pub fn setState(self: *@This(), on: bool, r: u8, g: u8, b: u8) void {
                self.on = on;
                self.r = r;
                self.g = g;
                self.b = b;
            }
        };

        inited: bool = false,
        deinited: bool = false,
        idx: usize = 0,
        events: [5]Event = .{
            .{ .op = "cmd", .t = 0, .dev = "sys", .v = .{ .action = "" } },
            .{ .op = "input", .t = 100, .dev = "btn_boot", .v = .{ .action = "press_down" } },
            .{ .op = "input", .t = 1200, .dev = "btn_boot", .v = .{ .action = "release" } },
            .{ .op = "input", .t = 2000, .dev = "btn_boot", .v = .{ .action = "press_down" } },
            .{ .op = "input", .t = 2050, .dev = "btn_boot", .v = .{ .action = "release" } },
        },
        led_dev: LedDevice = .{},

        pub fn init(self: *@This()) !void {
            self.inited = true;
        }

        pub fn deinit(self: *@This()) void {
            self.deinited = true;
        }

        pub fn nextEvent(self: *@This()) ?Event {
            if (self.idx >= self.events.len) return null;
            defer self.idx += 1;
            return self.events[self.idx];
        }
    };

    var runtime = Runtime{};
    var board = Board{};

    try run(&runtime, &board);

    try std.testing.expect(runtime.inited);
    try std.testing.expect(runtime.deinited);
    try std.testing.expect(board.inited);
    try std.testing.expect(board.deinited);
    try std.testing.expect(board.led_dev.on);
    try std.testing.expectEqual(@as(u8, 255), board.led_dev.r);
    try std.testing.expectEqual(@as(u8, 0), board.led_dev.g);
}
