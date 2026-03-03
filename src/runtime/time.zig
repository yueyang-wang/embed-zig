//! Runtime Time Contract

/// Time contract:
/// - `nowMs(self) -> u64`
/// - `sleepMs(self, ms: u32) -> void`
pub fn from(comptime Impl: type) type {
    comptime {
        const BaseType = switch (@typeInfo(Impl)) {
            .pointer => |p| p.child,
            else => Impl,
        };

        _ = @as(*const fn (BaseType) u64, &BaseType.nowMs);
        _ = @as(*const fn (BaseType, u32) void, &BaseType.sleepMs);
    }
    return Impl;
}
