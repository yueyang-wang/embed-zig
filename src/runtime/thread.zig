//! Runtime Thread Contract

const std = @import("std");

pub const TaskFn = *const fn (?*anyopaque) void;

pub const SpawnConfig = struct {
    stack_size: usize = 8192,
    priority: u8 = 5,
    name: [*:0]const u8 = "task",
    core_id: ?i32 = null,
    allocator: ?std.mem.Allocator = null,
};

const Seal = struct {};

/// Construct a Thread wrapper from an Impl type.
/// Impl must provide:
///   pub fn spawn(SpawnConfig, TaskFn, ?*anyopaque) anyerror!Impl
///   pub fn join(*Impl) void
///   pub fn detach(*Impl) void
pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (SpawnConfig, TaskFn, ?*anyopaque) anyerror!Impl, &Impl.spawn);
        _ = @as(*const fn (*Impl) void, &Impl.join);
        _ = @as(*const fn (*Impl) void, &Impl.detach);
    }

    return struct {
        pub const seal: Seal = .{};
        driver: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .driver = driver };
        }

        pub fn deinit(self: *Self) void {
            self.driver = undefined;
        }

        pub fn spawn(config: SpawnConfig, task: TaskFn, ctx: ?*anyopaque) anyerror!Self {
            return .{ .impl = try Impl.spawn(config, task, ctx) };
        }

        pub fn join(self: *Self) void {
            self.impl.join();
        }

        pub fn detach(self: *Self) void {
            self.impl.detach();
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
