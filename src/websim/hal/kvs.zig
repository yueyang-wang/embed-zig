//! Websim stub — KVS HAL (placeholder).

const kvs = @import("../../hal/kvs.zig");

pub const Kvs = struct {
    pub fn get(_: *Kvs, _: []const u8, _: []u8) kvs.Error!usize { return error.NotFound; }
    pub fn set(_: *Kvs, _: []const u8, _: []const u8) kvs.Error!void { return error.Unexpected; }
    pub fn delete(_: *Kvs, _: []const u8) kvs.Error!void { return error.NotFound; }
    pub fn has(_: *const Kvs, _: []const u8) bool { return false; }
    pub fn getU32(_: *Kvs, _: []const u8) kvs.Error!u32 { return error.NotFound; }
    pub fn setU32(_: *Kvs, _: []const u8, _: u32) kvs.Error!void { return error.Unexpected; }
    pub fn getI32(_: *Kvs, _: []const u8) kvs.Error!i32 { return error.NotFound; }
    pub fn setI32(_: *Kvs, _: []const u8, _: i32) kvs.Error!void { return error.Unexpected; }
    pub fn getU64(_: *Kvs, _: []const u8) kvs.Error!u64 { return error.NotFound; }
    pub fn setU64(_: *Kvs, _: []const u8, _: u64) kvs.Error!void { return error.Unexpected; }
    pub fn getI64(_: *Kvs, _: []const u8) kvs.Error!i64 { return error.NotFound; }
    pub fn setI64(_: *Kvs, _: []const u8, _: i64) kvs.Error!void { return error.Unexpected; }
    pub fn getBool(_: *Kvs, _: []const u8) kvs.Error!bool { return error.NotFound; }
    pub fn setBool(_: *Kvs, _: []const u8, _: bool) kvs.Error!void { return error.Unexpected; }
};
