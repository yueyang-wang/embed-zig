//! Runtime crypto P256 key-exchange contract.

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, [32]u8) anyerror![65]u8, &Impl.computePublicKey);
        _ = @as(*const fn (*Impl, [32]u8, [65]u8) anyerror![32]u8, &Impl.ecdh);
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

        pub fn computePublicKey(self: Self, secret_key: [32]u8) ![65]u8 {
            return self.impl.computePublicKey(secret_key);
        }

        pub fn ecdh(self: Self, secret_key: [32]u8, peer_public: [65]u8) ![32]u8 {
            return self.impl.ecdh(secret_key, peer_public);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
