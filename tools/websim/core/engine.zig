const std = @import("std");
const protocol = @import("protocol.zig");
const firmware = @import("firmware");

pub const EngineError = error{
    UnsupportedOperation,
    UnsupportedDevice,
    UnsupportedAction,
    MissingPayloadField,
};

pub const Engine = struct {
    backing: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    outbox: std.ArrayList(protocol.Message),
    app: firmware.App,
    cfg: firmware.Config,

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!Engine {
        return .{
            .backing = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .outbox = .empty,
            .app = firmware.App.init(),
            .cfg = .{
                .long_press_ms = firmware.spec.timing.long_press_ms,
                .double_click_window_ms = firmware.spec.timing.double_click_window_ms,
            },
        };
    }

    pub fn deinit(self: *Engine) void {
        self.outbox.deinit(self.backing);
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn cycleAllocator(self: *Engine) std.mem.Allocator {
        return self.arena.allocator();
    }

    pub fn resetCycle(self: *Engine) void {
        self.outbox.clearRetainingCapacity();
        _ = self.arena.reset(.retain_capacity);
    }

    pub fn applySend(self: *Engine, msg: protocol.Message) (EngineError || std.mem.Allocator.Error)!void {
        const action = parseAction(msg) orelse return error.UnsupportedAction;
        if (self.app.onInput(self.cfg, msg.t, action)) |led| {
            try self.enqueueLedOutput(msg.t, led);
        }
    }

    pub fn popOutbound(self: *Engine) ?protocol.Message {
        if (self.outbox.items.len == 0) return null;
        return self.outbox.orderedRemove(0);
    }

    pub fn hasPendingOutbound(self: *const Engine) bool {
        return self.outbox.items.len > 0;
    }

    pub fn pendingOutboundCount(self: *const Engine) usize {
        return self.outbox.items.len;
    }

    fn enqueueLedOutput(self: *Engine, t: u64, led: firmware.LedState) std.mem.Allocator.Error!void {
        const fields = try self.arena.allocator().alloc(protocol.Field, 4);
        fields[0] = .{ .key = "on", .value = .{ .boolean = led.on } };
        fields[1] = .{ .key = "r", .value = .{ .int = @intCast(led.r) } };
        fields[2] = .{ .key = "g", .value = .{ .int = @intCast(led.g) } };
        fields[3] = .{ .key = "b", .value = .{ .int = @intCast(led.b) } };

        try self.outbox.append(self.backing, .{
            .op = "set",
            .t = t,
            .dev = firmware.spec.devices.led,
            .v = .{ .fields = fields },
        });
    }
};

fn parseAction(msg: protocol.Message) ?firmware.InputAction {
    if (std.mem.eql(u8, msg.op, "cmd") and std.mem.eql(u8, msg.dev, "sys")) {
        const cmd = msg.v.getString("cmd") orelse return null;
        if (std.mem.eql(u8, cmd, "reset")) return .reset;
        return null;
    }

    if (std.mem.eql(u8, msg.op, "input") and std.mem.eql(u8, msg.dev, firmware.spec.devices.button)) {
        const action = msg.v.getString("action") orelse return null;
        if (std.mem.eql(u8, action, "press_down")) return .press_down;
        if (std.mem.eql(u8, action, "release")) return .release;
        return null;
    }

    return null;
}
