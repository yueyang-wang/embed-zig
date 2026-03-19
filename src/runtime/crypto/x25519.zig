//! Runtime crypto X25519 key-exchange contract.

const Seal = struct {};

pub const KeyPair = struct {
    public_key: [32]u8,
    secret_key: [32]u8,
};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, [32]u8) anyerror!KeyPair, &Impl.generateDeterministic);
        _ = @as(*const fn (*Impl, [32]u8, [32]u8) anyerror![32]u8, &Impl.scalarmult);
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

        pub fn generateDeterministic(self: Self, seed: [32]u8) !KeyPair {
            return self.impl.generateDeterministic(seed);
        }

        pub fn scalarmult(self: Self, secret: [32]u8, public: [32]u8) ![32]u8 {
            return self.impl.scalarmult(secret, public);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
