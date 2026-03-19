//! Runtime crypto hash contracts.

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, []const u8) void, &Impl.update);
        _ = @as(*const fn (*Impl, []const u8, *[32]u8) void, &Impl.sha256);
        _ = @as(*const fn (*Impl, []const u8, *[48]u8) void, &Impl.sha384);
        _ = @as(*const fn (*Impl, []const u8, *[64]u8) void, &Impl.sha512);
    }

    return struct {
        pub const seal: Seal = .{};
        impl: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .impl = driver };
        }

        pub fn deinit(self: *Self) void {
            self.impl = undefined;
        }

        pub fn update(self: Self, data: []const u8) void {
            self.impl.update(data);
        }

        pub fn sha256(self: Self, data: []const u8, out: *[32]u8) void {
            self.impl.sha256(data, out);
        }

        pub fn sha384(self: Self, data: []const u8, out: *[48]u8) void {
            self.impl.sha384(data, out);
        }

        pub fn sha512(self: Self, data: []const u8, out: *[64]u8) void {
            self.impl.sha512(data, out);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
