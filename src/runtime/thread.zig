//! Runtime Thread Contract

const std = @import("std");

pub const types = struct {
    pub const TaskFn = *const fn (?*anyopaque) void;
};

pub const SpawnConfig = struct {
    stack_size: usize = 8192,
    priority: u8 = 5,
    name: [*:0]const u8 = "task",
    core_id: ?i32 = null,
    allocator: ?std.mem.Allocator = null,
};

/// Thread contract:
/// - `spawn(config: SpawnConfig, task: TaskFn, ctx: ?*anyopaque) -> anyerror!Impl`
/// - `join(self: *Impl) -> void`
/// - `detach(self: *Impl) -> void`
pub fn from(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (SpawnConfig, types.TaskFn, ?*anyopaque) anyerror!Impl, &Impl.spawn);
        _ = @as(*const fn (*Impl) void, &Impl.join);
        _ = @as(*const fn (*Impl) void, &Impl.detach);
    }
    return Impl;
}
