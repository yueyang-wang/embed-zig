//! Runtime RNG Contract

pub const Error = error{
    RngFailed,
};

/// RNG contract:
/// - `fill(self, buf: []u8) -> Error!void`
pub fn from(comptime Impl: type) type {
    comptime {
        const BaseType = switch (@typeInfo(Impl)) {
            .pointer => |p| p.child,
            else => Impl,
        };

        _ = @as(*const fn (BaseType, []u8) Error!void, &BaseType.fill);
    }
    return Impl;
}
