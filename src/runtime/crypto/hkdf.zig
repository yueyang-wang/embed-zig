//! Runtime crypto HKDF contracts.

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, ?[]const u8, []const u8, *[32]u8) void, &Impl.sha256Extract);
        _ = @as(*const fn (*Impl, *const [32]u8, []const u8, []u8) void, &Impl.sha256Expand);
        _ = @as(*const fn (*Impl, ?[]const u8, []const u8, *[48]u8) void, &Impl.sha384Extract);
        _ = @as(*const fn (*Impl, *const [48]u8, []const u8, []u8) void, &Impl.sha384Expand);
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

        pub fn sha256Extract(self: Self, salt: ?[]const u8, ikm: []const u8, out: *[32]u8) void {
            self.impl.sha256Extract(salt, ikm, out);
        }

        pub fn sha256Expand(self: Self, prk: *const [32]u8, ctx: []const u8, out: []u8) void {
            self.impl.sha256Expand(prk, ctx, out);
        }

        pub fn sha384Extract(self: Self, salt: ?[]const u8, ikm: []const u8, out: *[48]u8) void {
            self.impl.sha384Extract(salt, ikm, out);
        }

        pub fn sha384Expand(self: Self, prk: *const [48]u8, ctx: []const u8, out: []u8) void {
            self.impl.sha384Expand(prk, ctx, out);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
