//! Runtime Log Contract

const std = @import("std");

/// Log level used by sinks/backends.
pub const Level = enum {
    debug,
    info,
    warn,
    err,
};

/// Log contract:
/// - `debug(self, msg: []const u8) -> void`
/// - `info(self, msg: []const u8) -> void`
/// - `warn(self, msg: []const u8) -> void`
/// - `err(self, msg: []const u8) -> void`
///
/// Also provides fmt convenience methods via the returned wrapper:
/// - `debugFmt(self, comptime fmt, args) -> void`
/// - `infoFmt(self, comptime fmt, args) -> void`
/// - `warnFmt(self, comptime fmt, args) -> void`
/// - `errFmt(self, comptime fmt, args) -> void`
pub fn from(comptime Impl: type) type {
    comptime {
        const BaseType = switch (@typeInfo(Impl)) {
            .pointer => |p| p.child,
            else => Impl,
        };

        _ = @as(*const fn (BaseType, []const u8) void, &BaseType.debug);
        _ = @as(*const fn (BaseType, []const u8) void, &BaseType.info);
        _ = @as(*const fn (BaseType, []const u8) void, &BaseType.warn);
        _ = @as(*const fn (BaseType, []const u8) void, &BaseType.err);
    }

    return struct {
        const impl: Impl = .{};

        pub fn debug(_: @This(), msg: []const u8) void {
            impl.debug(msg);
        }

        pub fn info(_: @This(), msg: []const u8) void {
            impl.info(msg);
        }

        pub fn warn(_: @This(), msg: []const u8) void {
            impl.warn(msg);
        }

        pub fn err(_: @This(), msg: []const u8) void {
            impl.err(msg);
        }

        pub fn debugFmt(_: @This(), comptime fmt: []const u8, args: anytype) void {
            logFmt(.debug, fmt, args);
        }

        pub fn infoFmt(_: @This(), comptime fmt: []const u8, args: anytype) void {
            logFmt(.info, fmt, args);
        }

        pub fn warnFmt(_: @This(), comptime fmt: []const u8, args: anytype) void {
            logFmt(.warn, fmt, args);
        }

        pub fn errFmt(_: @This(), comptime fmt: []const u8, args: anytype) void {
            logFmt(.err, fmt, args);
        }

        fn logFmt(comptime level: Level, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, fmt, args) catch &buf;
            switch (level) {
                .debug => impl.debug(msg),
                .info => impl.info(msg),
                .warn => impl.warn(msg),
                .err => impl.err(msg),
            }
        }
    };
}
