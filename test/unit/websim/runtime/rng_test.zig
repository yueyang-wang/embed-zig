const std = @import("std");
const embed = @import("embed");
const Std = embed.runtime.std;

const RawRng = @typeInfo(@TypeOf(@as(Std.Rng, undefined).impl)).pointer.child;
var raw_rng: RawRng = .{};
const std_rng = Std.Rng.init(&raw_rng);

test "std rng fills bytes" {
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    try std_rng.fill(&a);
    try std_rng.fill(&b);
    try std.testing.expect(!std.mem.eql(u8, &a, &b));
}
