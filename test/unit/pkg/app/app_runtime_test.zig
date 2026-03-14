const std = @import("std");
const embed = @import("embed");
const module = embed.pkg.app;
const AppRuntime = module.AppRuntime;

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

const TestApp = struct {
    pub const State = struct {
        count: u32 = 0,
    };

    pub const Event = union(enum) {
        tick,
        increment,
    };

    pub fn reduce(state: *State, ev: Event) void {
        switch (ev) {
            .tick => {},
            .increment => state.count += 1,
        }
    }
};

const StdIO = embed.runtime.std.Selector(TestApp.Event);

test "AppRuntime: inject dispatches to reducer" {
    var io = try StdIO.init(testing.allocator, &.{});
    defer io.deinit();

    var rt = AppRuntime(TestApp, StdIO).init(
        testing.allocator,
        &io,
        .{ .poll_timeout_ms = 0 },
    );
    defer rt.deinit();

    rt.inject(.increment);
    try testing.expectEqual(@as(u32, 1), rt.getState().count);
    try testing.expect(rt.isDirty());

    rt.commitFrame();
    try testing.expect(!rt.isDirty());
}

test "AppRuntime: tick with no events does not re-dirty" {
    var io = try StdIO.init(testing.allocator, &.{});
    defer io.deinit();

    var rt = AppRuntime(TestApp, StdIO).init(
        testing.allocator,
        &io,
        .{ .poll_timeout_ms = 0 },
    );
    defer rt.deinit();

    rt.commitFrame();
    try testing.expect(!rt.isDirty());

    io.wake();
    rt.tick();
    try testing.expect(!rt.isDirty());
}

test "AppRuntime: commitFrame resets dirty" {
    var io = try StdIO.init(testing.allocator, &.{});
    defer io.deinit();

    var rt = AppRuntime(TestApp, StdIO).init(
        testing.allocator,
        &io,
        .{ .poll_timeout_ms = 0 },
    );
    defer rt.deinit();

    rt.inject(.increment);
    try testing.expect(rt.isDirty());
    try testing.expectEqual(@as(u32, 1), rt.getState().count);

    rt.commitFrame();
    try testing.expect(!rt.isDirty());

    rt.inject(.increment);
    try testing.expect(rt.isDirty());
    try testing.expectEqual(@as(u32, 2), rt.getState().count);
}
