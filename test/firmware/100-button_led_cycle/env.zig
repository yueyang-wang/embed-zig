const std = @import("std");
const app_mod = @import("app.zig");

pub const Error = error{
    UnsupportedOperation,
};

pub fn processEvent(app: *app_mod.App, cfg: app_mod.Config, board: anytype, event: anytype) !void {
    const parsed = parseEvent(event) orelse return;
    if (app.onInput(cfg, parsed.t, parsed.action)) |led| {
        applyLed(board, led);
    }
}

const ParsedEvent = struct {
    t: u64,
    action: app_mod.InputAction,
};

fn parseEvent(event: anytype) ?ParsedEvent {
    const EventType = @TypeOf(event);
    if (@typeInfo(EventType) != .@"struct") return null;

    if (!@hasField(EventType, "op") or !@hasField(EventType, "dev") or !@hasField(EventType, "t") or !@hasField(EventType, "v")) {
        return null;
    }

    const op = @field(event, "op");
    const dev = @field(event, "dev");
    const t = @field(event, "t");
    const v = @field(event, "v");

    if (@TypeOf(op) != []const u8 or @TypeOf(dev) != []const u8 or @TypeOf(t) != u64) {
        return null;
    }

    if (std.mem.eql(u8, op, "cmd") and std.mem.eql(u8, dev, "sys")) {
        if (payloadString(v, "cmd")) |cmd| {
            if (std.mem.eql(u8, cmd, "reset")) {
                return .{ .t = t, .action = .reset };
            }
        }
        return null;
    }

    if (std.mem.eql(u8, op, "input") and std.mem.eql(u8, dev, "btn_boot")) {
        if (payloadString(v, "action")) |action| {
            if (std.mem.eql(u8, action, "press_down")) {
                return .{ .t = t, .action = .press_down };
            }
            if (std.mem.eql(u8, action, "release")) {
                return .{ .t = t, .action = .release };
            }
        }
    }

    return null;
}

fn payloadString(payload: anytype, comptime key: []const u8) ?[]const u8 {
    const PayloadType = @TypeOf(payload);
    if (@typeInfo(PayloadType) != .@"struct") return null;

    if (@hasDecl(PayloadType, "getString")) {
        return payload.getString(key);
    }

    if (@hasField(PayloadType, key)) {
        const value = @field(payload, key);
        if (@TypeOf(value) == []const u8) return value;
    }

    return null;
}

fn applyLed(board: anytype, led: app_mod.LedState) void {
    const BoardType = @TypeOf(board);
    if (@typeInfo(BoardType) != .pointer) return;
    const BoardValue = @typeInfo(BoardType).pointer.child;

    if (@hasField(BoardValue, "led_dev")) {
        applyLedDevice(&@field(board.*, "led_dev"), led);
    }
}

fn applyLedDevice(led_dev: anytype, led: app_mod.LedState) void {
    const LedType = @TypeOf(led_dev.*);

    if (comptime @hasDecl(LedType, "setState")) {
        led_dev.setState(led.on, led.r, led.g, led.b);
        return;
    }

    if (comptime @hasDecl(LedType, "setRgb")) {
        led_dev.setRgb(led.r, led.g, led.b);
        if (comptime @hasDecl(LedType, "setEnabled")) {
            led_dev.setEnabled(led.on);
        } else if (led.on and comptime @hasDecl(LedType, "on")) {
            led_dev.on();
        } else if (!led.on and comptime @hasDecl(LedType, "off")) {
            led_dev.off();
        }
        return;
    }

    if (comptime @hasDecl(LedType, "setBrightness")) {
        if (!led.on) {
            led_dev.setBrightness(0);
            return;
        }
        const max_component = @max(led.r, @max(led.g, led.b));
        led_dev.setBrightness(max_component);
        return;
    }

    if (led.on and comptime @hasDecl(LedType, "on")) {
        led_dev.on();
    } else if (!led.on and comptime @hasDecl(LedType, "off")) {
        led_dev.off();
    }
}

test "env parses protocol-like event" {
    const Event = struct {
        op: []const u8,
        t: u64,
        dev: []const u8,
        v: struct {
            action: []const u8,
        },
    };

    const parsed = parseEvent(Event{
        .op = "input",
        .t = 123,
        .dev = "btn_boot",
        .v = .{ .action = "press_down" },
    }) orelse return error.ExpectedParsed;

    try std.testing.expectEqual(@as(u64, 123), parsed.t);
    try std.testing.expectEqual(app_mod.InputAction.press_down, parsed.action);
}
