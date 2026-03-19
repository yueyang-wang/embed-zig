const std = @import("std");
const embed = @import("embed");
const Std = embed.runtime.std;

const RawTime = @typeInfo(@TypeOf(@as(Std.Time, undefined).impl)).pointer.child;
var raw_time: RawTime = .{};
const std_time = Std.Time.init(&raw_time);

test "std time nowMs returns positive value" {
    const now = std_time.nowMs();
    try std.testing.expect(now > 0);
}
