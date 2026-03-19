//! Runtime crypto PKI/signature contracts.

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, []const u8, []const u8, []const u8) bool, &Impl.verifyEd25519);
        _ = @as(*const fn (*Impl, []const u8, []const u8, []const u8) bool, &Impl.verifyEcdsaP256);
        _ = @as(*const fn (*Impl, []const u8, []const u8, []const u8) bool, &Impl.verifyEcdsaP384);
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

        pub fn verifyEd25519(self: Self, sig: []const u8, msg: []const u8, pk: []const u8) bool {
            return self.impl.verifyEd25519(sig, msg, pk);
        }

        pub fn verifyEcdsaP256(self: Self, sig: []const u8, msg: []const u8, pk: []const u8) bool {
            return self.impl.verifyEcdsaP256(sig, msg, pk);
        }

        pub fn verifyEcdsaP384(self: Self, sig: []const u8, msg: []const u8, pk: []const u8) bool {
            return self.impl.verifyEcdsaP384(sig, msg, pk);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
