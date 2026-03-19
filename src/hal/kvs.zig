//! HAL Key-Value Store Contract
//!
//! Persistent key-value storage backed by flash (NVS), EEPROM, or
//! file-based storage depending on platform.
//!
//! Impl must provide:
//!   get/set/delete/has for raw bytes,
//!   getU32/setU32, getI32/setI32,
//!   getU64/setU64, getI64/setI64,
//!   getBool/setBool
//!   for native primitive storage.

pub const Error = error{
    NotFound,
    NoSpace,
    KeyTooLong,
    ValueTooLong,
    TypeMismatch,
    IoError,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        // bytes
        _ = @as(*const fn (*Impl, []const u8, []u8) Error!usize, &Impl.get);
        _ = @as(*const fn (*Impl, []const u8, []const u8) Error!void, &Impl.set);
        _ = @as(*const fn (*Impl, []const u8) Error!void, &Impl.delete);
        _ = @as(*const fn (*const Impl, []const u8) bool, &Impl.has);

        // u32 / i32
        _ = @as(*const fn (*Impl, []const u8) Error!u32, &Impl.getU32);
        _ = @as(*const fn (*Impl, []const u8, u32) Error!void, &Impl.setU32);
        _ = @as(*const fn (*Impl, []const u8) Error!i32, &Impl.getI32);
        _ = @as(*const fn (*Impl, []const u8, i32) Error!void, &Impl.setI32);

        // u64 / i64
        _ = @as(*const fn (*Impl, []const u8) Error!u64, &Impl.getU64);
        _ = @as(*const fn (*Impl, []const u8, u64) Error!void, &Impl.setU64);
        _ = @as(*const fn (*Impl, []const u8) Error!i64, &Impl.getI64);
        _ = @as(*const fn (*Impl, []const u8, i64) Error!void, &Impl.setI64);

        // bool
        _ = @as(*const fn (*Impl, []const u8) Error!bool, &Impl.getBool);
        _ = @as(*const fn (*Impl, []const u8, bool) Error!void, &Impl.setBool);
    }

    return struct {
        pub const seal: Seal = .{};
        driver: *Impl,

        const Self = @This();

        pub fn init(driver: *Impl) Self {
            return .{ .driver = driver };
        }

        pub fn deinit(self: *Self) void {
            self.driver = undefined;
        }

        // -- bytes --

        pub fn get(self: Self, key: []const u8, buf: []u8) Error!usize {
            return self.driver.get(key, buf);
        }

        pub fn set(self: Self, key: []const u8, value: []const u8) Error!void {
            return self.driver.set(key, value);
        }

        pub fn delete(self: Self, key: []const u8) Error!void {
            return self.driver.delete(key);
        }

        pub fn has(self: Self, key: []const u8) bool {
            return self.driver.has(key);
        }

        // -- u32 / i32 --

        pub fn getU32(self: Self, key: []const u8) Error!u32 {
            return self.driver.getU32(key);
        }

        pub fn setU32(self: Self, key: []const u8, value: u32) Error!void {
            return self.driver.setU32(key, value);
        }

        pub fn getI32(self: Self, key: []const u8) Error!i32 {
            return self.driver.getI32(key);
        }

        pub fn setI32(self: Self, key: []const u8, value: i32) Error!void {
            return self.driver.setI32(key, value);
        }

        // -- u64 / i64 --

        pub fn getU64(self: Self, key: []const u8) Error!u64 {
            return self.driver.getU64(key);
        }

        pub fn setU64(self: Self, key: []const u8, value: u64) Error!void {
            return self.driver.setU64(key, value);
        }

        pub fn getI64(self: Self, key: []const u8) Error!i64 {
            return self.driver.getI64(key);
        }

        pub fn setI64(self: Self, key: []const u8, value: i64) Error!void {
            return self.driver.setI64(key, value);
        }

        // -- bool --

        pub fn getBool(self: Self, key: []const u8) Error!bool {
            return self.driver.getBool(key);
        }

        pub fn setBool(self: Self, key: []const u8, value: bool) Error!void {
            return self.driver.setBool(key, value);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
