//! Runtime crypto AEAD contracts.

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, []u8, *[16]u8, []const u8, []const u8, [12]u8, []const u8) void, &Impl.encrypt);
        _ = @as(*const fn (*Impl, []u8, []const u8, [16]u8, []const u8, [12]u8, []const u8) error{AuthenticationFailed}!void, &Impl.decrypt);
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

        pub fn encrypt(self: Self, buf: []u8, tag: *[16]u8, plaintext: []const u8, ad: []const u8, nonce: [12]u8, key: []const u8) void {
            self.impl.encrypt(buf, tag, plaintext, ad, nonce, key);
        }

        pub fn decrypt(self: Self, buf: []u8, ciphertext: []const u8, tag: [16]u8, ad: []const u8, nonce: [12]u8, key: []const u8) error{AuthenticationFailed}!void {
            return self.impl.decrypt(buf, ciphertext, tag, ad, nonce, key);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
