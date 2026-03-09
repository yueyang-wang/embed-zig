const std = @import("std");
const runtime = @import("../../mod.zig").runtime;

pub const Rng = struct {
    pub fn fill(_: Rng, buf: []u8) runtime.rng.Error!void {
        std.crypto.random.bytes(buf);
    }
};
