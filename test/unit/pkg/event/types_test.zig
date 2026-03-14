const std = @import("std");
const testing = std.testing;
const embed = @import("embed");
const module = embed.pkg.event.types;
const PeriphEvent = module.PeriphEvent;
const CustomEvent = module.CustomEvent;
const SystemEvent = module.SystemEvent;
const TimerEvent = module.TimerEvent;
const assertTaggedUnion = module.assertTaggedUnion;

test "PeriphEvent can be instantiated" {
    const ev = PeriphEvent{ .id = "btn.test", .code = 2, .data = 3 };
    try std.testing.expectEqualStrings("btn.test", ev.id);
    try std.testing.expectEqual(@as(u16, 2), ev.code);
}

test "assertTaggedUnion accepts tagged union" {
    const Good = union(enum) { a: u32, b: f32 };
    comptime assertTaggedUnion(Good);
}
