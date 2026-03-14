const std = @import("std");
const embed = @import("embed");
const time = embed.runtime.std.std_time;

const std_time: time.Time = .{};

test "std time nowMs returns positive value" {
    const now = std_time.nowMs();
    try std.testing.expect(now > 0);
}
