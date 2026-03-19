//! Runtime crypto HMAC contracts.

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, *[32]u8, []const u8, []const u8) void, &Impl.sha256);
        _ = @as(*const fn (*Impl, *[48]u8, []const u8, []const u8) void, &Impl.sha384);
        _ = @as(*const fn (*Impl, *[64]u8, []const u8, []const u8) void, &Impl.sha512);
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

        pub fn sha256(self: Self, out: *[32]u8, msg: []const u8, key: []const u8) void {
            self.impl.sha256(out, msg, key);
        }

        pub fn sha384(self: Self, out: *[48]u8, msg: []const u8, key: []const u8) void {
            self.impl.sha384(out, msg, key);
        }

        pub fn sha512(self: Self, out: *[64]u8, msg: []const u8, key: []const u8) void {
            self.impl.sha512(out, msg, key);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
