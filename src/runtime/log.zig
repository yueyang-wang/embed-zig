//! Runtime Log Contract

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

    return Impl;
}
