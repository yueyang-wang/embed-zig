//! HAL BLE Peripheral Contract
//!
//! BLE Peripheral (server role): advertise, accept connections,
//! serve GATT requests via registered handlers.
//!
//! Design follows the http.ServeMux pattern:
//!
//!   | HTTP                | BLE Peripheral                       |
//!   |---------------------|--------------------------------------|
//!   | ListenAndServe      | startAdvertising                     |
//!   | HandleFunc(path,fn) | handle(svc_uuid, char_uuid, fn, ctx) |
//!   | http.Request        | Request (op, conn, data)             |
//!   | http.ResponseWriter | ResponseWriter (write, ok, err)      |
//!   | Shutdown            | stopAdvertising                      |
//!   | Server Push / SSE   | notify / indicate                    |
//!
//! Impl must provide all methods listed in the Make() comptime checks.

pub const BdAddr = [6]u8;

pub const State = enum {
    idle,
    advertising,
    connected,
};

pub const AdvConfig = struct {
    device_name: []const u8 = "",
    service_uuids: []const u16 = &.{},
    interval_min: u16 = 0x0800,
    interval_max: u16 = 0x0800,
    connectable: bool = true,
    adv_data: []const u8 = &.{},
    scan_rsp_data: []const u8 = &.{},
};

pub const Operation = enum {
    read,
    write,
    write_command,
};

pub const Request = struct {
    op: Operation,
    conn_handle: u16,
    service_uuid: u16,
    char_uuid: u16,
    data: []const u8,
    user_ctx: ?*anyopaque,
};

pub const ResponseWriter = struct {
    _impl: *anyopaque,
    _write_fn: *const fn (*anyopaque, []const u8) void,
    _ok_fn: *const fn (*anyopaque) void,
    _err_fn: *const fn (*anyopaque, u8) void,

    pub fn write(self: *ResponseWriter, data: []const u8) void {
        self._write_fn(self._impl, data);
    }

    pub fn ok(self: *ResponseWriter) void {
        self._ok_fn(self._impl);
    }

    pub fn err(self: *ResponseWriter, code: u8) void {
        self._err_fn(self._impl, code);
    }
};

pub const HandlerFn = *const fn (*Request, *ResponseWriter) void;

pub const ConnectionInfo = struct {
    conn_handle: u16,
    peer_addr: BdAddr,
    peer_addr_type: AddrType,
    interval: u16,
    latency: u16,
    timeout: u16,
};

pub const AddrType = enum {
    public,
    random,
};

pub const PeripheralEvent = union(enum) {
    connected: ConnectionInfo,
    disconnected: u16,
    advertising_started: void,
    advertising_stopped: void,
    mtu_changed: MtuInfo,
};

pub const MtuInfo = struct {
    conn_handle: u16,
    mtu: u16,
};

pub const AdvError = error{
    InvalidConfig,
    AlreadyAdvertising,
    Unexpected,
};

pub const GattError = error{
    InvalidHandle,
    NotConnected,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        // advertising
        _ = @as(*const fn (*Impl, AdvConfig) AdvError!void, &Impl.startAdvertising);
        _ = @as(*const fn (*Impl) void, &Impl.stopAdvertising);

        // handler registration
        _ = @as(*const fn (*Impl, u16, u16, HandlerFn, ?*anyopaque) void, &Impl.handle);

        // server push
        _ = @as(*const fn (*Impl, u16, u16, []const u8) GattError!void, &Impl.notify);
        _ = @as(*const fn (*Impl, u16, u16, []const u8) GattError!void, &Impl.indicate);

        // connection
        _ = @as(*const fn (*Impl, u16) void, &Impl.disconnect);
        _ = @as(*const fn (*const Impl) State, &Impl.getState);

        // event
        _ = @as(*const fn (*Impl, ?*anyopaque, *const fn (?*anyopaque, PeripheralEvent) void) void, &Impl.addEventHook);

        // info
        _ = @as(*const fn (*const Impl) ?BdAddr, &Impl.getAddr);
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

        // -- advertising --

        pub fn startAdvertising(self: Self, config: AdvConfig) AdvError!void {
            return self.driver.startAdvertising(config);
        }

        pub fn stopAdvertising(self: Self) void {
            self.driver.stopAdvertising();
        }

        // -- handler registration --

        pub fn handle(self: Self, svc_uuid: u16, char_uuid: u16, func: HandlerFn, ctx: ?*anyopaque) void {
            self.driver.handle(svc_uuid, char_uuid, func, ctx);
        }

        // -- server push --

        pub fn notify(self: Self, conn_handle: u16, char_uuid: u16, data: []const u8) GattError!void {
            return self.driver.notify(conn_handle, char_uuid, data);
        }

        pub fn indicate(self: Self, conn_handle: u16, char_uuid: u16, data: []const u8) GattError!void {
            return self.driver.indicate(conn_handle, char_uuid, data);
        }

        // -- connection --

        pub fn disconnect(self: Self, conn_handle: u16) void {
            self.driver.disconnect(conn_handle);
        }

        pub fn getState(self: Self) State {
            return self.driver.getState();
        }

        // -- event --

        pub fn addEventHook(self: Self, ctx: ?*anyopaque, call: *const fn (?*anyopaque, PeripheralEvent) void) void {
            self.driver.addEventHook(ctx, call);
        }

        // -- info --

        pub fn getAddr(self: Self) ?BdAddr {
            return self.driver.getAddr();
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
