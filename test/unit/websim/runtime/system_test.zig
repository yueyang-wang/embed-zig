const std = @import("std");
const embed = @import("embed");
const Std = embed.runtime.std;

const RawSystem = @typeInfo(@TypeOf(@as(Std.System, undefined).impl)).pointer.child;
var raw_system: RawSystem = .{};
const std_system = Std.System.init(&raw_system);

test "std system getCpuCount" {
    const cpu = try std_system.getCpuCount();
    try std.testing.expect(cpu >= 1);
}
