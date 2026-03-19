//! Runtime FS Contract

pub const OpenMode = enum {
    read,
    write,
    read_write,
};

pub const Error = error{
    NotFound,
    PermissionDenied,
    IoError,
    NoSpace,
    InvalidPath,
};

/// Runtime file handle.
pub const File = struct {
    data: ?[]const u8 = null,
    ctx: *anyopaque,
    readFn: ?*const fn (ctx: *anyopaque, buf: []u8) Error!usize = null,
    writeFn: ?*const fn (ctx: *anyopaque, buf: []const u8) Error!usize = null,
    closeFn: *const fn (ctx: *anyopaque) void,
    size: u32,

    pub fn read(self: *File, buf: []u8) Error!usize {
        const f = self.readFn orelse return Error.PermissionDenied;
        return f(self.ctx, buf);
    }

    pub fn write(self: *File, buf: []const u8) Error!usize {
        const f = self.writeFn orelse return Error.PermissionDenied;
        return f(self.ctx, buf);
    }

    pub fn close(self: *File) void {
        self.closeFn(self.ctx);
    }

    pub fn readAll(self: *File, buf: []u8) Error![]const u8 {
        var total: usize = 0;
        while (total < buf.len) {
            const n = try self.read(buf[total..]);
            if (n == 0) break;
            total += n;
        }
        return buf[0..total];
    }
};

const Seal = struct {};

/// Construct a sealed FileSystem wrapper from a backend Impl type.
/// Impl must provide: open(self: *Impl, path: []const u8, mode: OpenMode) ?File
pub fn Make(comptime Impl: type) type {
    comptime {
        _ = @as(*const fn (*Impl, []const u8, OpenMode) ?File, &Impl.open);
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

        pub fn open(self: Self, path: []const u8, mode: OpenMode) ?File {
            return self.impl.open(path, mode);
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
