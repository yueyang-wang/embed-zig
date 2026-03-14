const std = @import("std");
const embed = @import("embed");
const rng = embed.runtime.std.std_rng;

const std_rng: rng.Rng = .{};

test "std rng fills bytes" {
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    try std_rng.fill(&a);
    try std_rng.fill(&b);
    try std.testing.expect(!std.mem.eql(u8, &a, &b));
}
