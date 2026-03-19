const std = @import("std");
const rng_contract = @import("../runtime/rng.zig");

pub const Rng = struct {
    pub fn fill(_: *Rng, buf: []u8) rng_contract.Error!void {
        std.crypto.random.bytes(buf);
    }
};
