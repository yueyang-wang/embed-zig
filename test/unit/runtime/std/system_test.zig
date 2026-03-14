const std = @import("std");
const embed = @import("embed");
const system = embed.runtime.std.std_system;

const std_system: system.System = .{};

test "std system getCpuCount" {
    const cpu = try std_system.getCpuCount();
    try std.testing.expect(cpu >= 1);
}
