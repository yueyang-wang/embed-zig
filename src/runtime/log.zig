//! Runtime Log Contract

const std = @import("std");

pub const Level = enum {
    debug,
    info,
    warn,
    err,
};

const Seal = struct {};

/// Construct a Log wrapper from an Impl type.
/// Impl must provide: debug, info, warn, err — all `fn(Impl, []const u8) void`.
/// The returned type also provides debugFmt/infoFmt/warnFmt/errFmt convenience methods.
pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, []const u8) void, &Impl.debug);
        _ = @as(*const fn (*Impl, []const u8) void, &Impl.info);
        _ = @as(*const fn (*Impl, []const u8) void, &Impl.warn);
        _ = @as(*const fn (*Impl, []const u8) void, &Impl.err);
    }

    const LogType = struct {
        pub const seal: Seal = .{};

        impl: *Impl,

        const Self = @This();

        pub fn init(impl: *Impl) Self {
            return .{ .impl = impl };
        }

        pub fn deinit(self: *Self) void {
            self.impl = undefined;
        }

        pub fn debug(self: Self, msg: []const u8) void {
            self.impl.debug(msg);
        }

        pub fn info(self: Self, msg: []const u8) void {
            self.impl.info(msg);
        }

        pub fn warn(self: Self, msg: []const u8) void {
            self.impl.warn(msg);
        }

        pub fn err(self: Self, msg: []const u8) void {
            self.impl.err(msg);
        }

        pub fn debugFmt(self: Self, comptime fmt: []const u8, args: anytype) void {
            self.logFmt(.debug, fmt, args);
        }

        pub fn infoFmt(self: Self, comptime fmt: []const u8, args: anytype) void {
            self.logFmt(.info, fmt, args);
        }

        pub fn warnFmt(self: Self, comptime fmt: []const u8, args: anytype) void {
            self.logFmt(.warn, fmt, args);
        }

        pub fn errFmt(self: Self, comptime fmt: []const u8, args: anytype) void {
            self.logFmt(.err, fmt, args);
        }

        fn logFmt(self: Self, comptime level: Level, comptime fmt: []const u8, args: anytype) void {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, fmt, args) catch &buf;
            switch (level) {
                .debug => self.impl.debug(msg),
                .info => self.impl.info(msg),
                .warn => self.impl.warn(msg),
                .err => self.impl.err(msg),
            }
        }
    };
    return LogType;
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
