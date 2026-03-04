//! Driver package aggregate entry point.
//!
//! Exports all available hardware drivers.
//! Each driver is generic over its bus spec for platform independence.

pub const es8311 = @import("es8311/src.zig");
pub const Es8311 = es8311.Es8311;
pub const es7210 = @import("es7210/src.zig");
pub const Es7210 = es7210.Es7210;

test {
    _ = es8311;
    _ = es7210;
}
