//! Runtime OTA backend contract (write + confirm/rollback lifecycle).

pub const Error = error{
    InitFailed,
    OpenFailed,
    WriteFailed,
    FinalizeFailed,
    AbortFailed,
    ConfirmFailed,
    RollbackFailed,
};

pub const State = enum {
    unknown,
    pending_verify,
    valid,
    invalid,
};

const Seal = struct {};

/// Construct a sealed OtaBackend wrapper from a backend Impl type.
/// Impl must provide: begin, write, finalize, abort, confirm, rollback, getState.
pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, u32) Error!void, &Impl.begin);
        _ = @as(*const fn (*Impl, []const u8) Error!void, &Impl.write);
        _ = @as(*const fn (*Impl) Error!void, &Impl.finalize);
        _ = @as(*const fn (*Impl) void, &Impl.abort);
        _ = @as(*const fn (*Impl) Error!void, &Impl.confirm);
        _ = @as(*const fn (*Impl) Error!void, &Impl.rollback);
        _ = @as(*const fn (*Impl) State, &Impl.getState);
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

        pub fn begin(self: Self, image_size: u32) Error!void {
            return self.impl.begin(image_size);
        }

        pub fn write(self: Self, chunk: []const u8) Error!void {
            return self.impl.write(chunk);
        }

        pub fn finalize(self: Self) Error!void {
            return self.impl.finalize();
        }

        pub fn abort(self: Self) void {
            self.impl.abort();
        }

        pub fn confirm(self: Self) Error!void {
            return self.impl.confirm();
        }

        pub fn rollback(self: Self) Error!void {
            return self.impl.rollback();
        }

        pub fn getState(self: Self) State {
            return self.impl.getState();
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
