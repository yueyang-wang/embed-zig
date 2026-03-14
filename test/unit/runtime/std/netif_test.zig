const std = @import("std");
const embed = @import("embed");
const netif = embed.runtime.std.std_netif;

const std_netif: netif.NetIf = .{};

test "std netif dns and default interface" {
    const names = std_netif.list();
    try std.testing.expect(names.len >= 1);

    const maybe_info = std_netif.get(names[0]);
    try std.testing.expect(maybe_info != null);

    std_netif.setDefault(names[0]);
    const def = std_netif.getDefault().?;
    try std.testing.expect(std.mem.eql(u8, &def, &names[0]));

    std_netif.setDns(.{ 9, 9, 9, 9 }, .{ 8, 8, 4, 4 });
    const dns = std_netif.getDns();
    try std.testing.expectEqual(@as(u8, 9), dns.primary[0]);
    try std.testing.expectEqual(@as(u8, 8), dns.secondary[0]);
}
