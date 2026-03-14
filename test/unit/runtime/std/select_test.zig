const std = @import("std");
const embed = @import("embed");
const channel = embed.runtime.std.std_channel;
const sel = embed.runtime.std.std_select;
const runner = embed.runtime.test_runners.select;

const StdChannel = channel.Channel(u32);
const StdSelector = sel.Selector(u32);
const TestRunner = runner.SelectTestRunner(StdSelector, StdChannel);

test "std select passes basic tests" {
    try TestRunner.run(std.testing.allocator, .{ .basic = true });
}

test "std select passes concurrency tests" {
    try TestRunner.run(std.testing.allocator, .{ .concurrency = true });
}
