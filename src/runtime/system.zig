//! Runtime System Contract

/// Fixed error set for system queries.
pub const Error = error{
    Unsupported,
    QueryFailed,
};

/// System contract:
/// - `getCpuCount(self) -> Error!usize`
pub fn from(comptime Impl: type) type {
    comptime {
        const BaseType = switch (@typeInfo(Impl)) {
            .pointer => |p| p.child,
            else => Impl,
        };

        _ = @as(*const fn (BaseType) Error!usize, &BaseType.getCpuCount);
    }
    return Impl;
}
