//! HAL BLE Central Contract
//!
//! BLE Central (client role): scan for devices, establish connections,
//! discover remote services, and read/write remote GATT characteristics.
//!
//! Blocking request-response model — each GATT operation completes
//! or returns an error. The driver handles ATT serialization internally.
//!
//! Impl must provide all methods listed in the Make() comptime checks.

pub const BdAddr = [6]u8;

pub const AddrType = enum {
    public,
    random,
};

pub const State = enum {
    idle,
    scanning,
    connecting,
    connected,
};

pub const ScanConfig = struct {
    active: bool = true,
    interval_ms: u16 = 10,
    window_ms: u16 = 10,
    filter_duplicates: bool = true,
    timeout_ms: u32 = 0,
};

pub const ConnParams = struct {
    interval_min: u16 = 0x0006,
    interval_max: u16 = 0x0006,
    latency: u16 = 0,
    timeout: u16 = 0x00C8,
};

pub const AdvReport = struct {
    addr: BdAddr,
    addr_type: AddrType,
    rssi: i8,
    name: [32]u8 = .{0} ** 32,
    name_len: u8 = 0,
    data: [31]u8 = .{0} ** 31,
    data_len: u8 = 0,

    pub fn getName(self: *const AdvReport) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getData(self: *const AdvReport) []const u8 {
        return self.data[0..self.data_len];
    }
};

pub const ConnectionInfo = struct {
    conn_handle: u16,
    peer_addr: BdAddr,
    peer_addr_type: AddrType,
    interval: u16,
    latency: u16,
    timeout: u16,
};

pub const DiscoveredService = struct {
    start_handle: u16,
    end_handle: u16,
    uuid: u16,
};

pub const DiscoveredChar = struct {
    decl_handle: u16,
    value_handle: u16,
    cccd_handle: u16,
    properties: u8,
    uuid: u16,
};

pub const NotificationData = struct {
    conn_handle: u16,
    attr_handle: u16,
    data: [247]u8 = undefined,
    len: u8 = 0,

    pub fn payload(self: *const NotificationData) []const u8 {
        return self.data[0..self.len];
    }
};

pub const CentralEvent = union(enum) {
    device_found: AdvReport,
    connected: ConnectionInfo,
    disconnected: u16,
    notification: NotificationData,
};

pub const ScanError = error{
    Busy,
    Unexpected,
};

pub const ConnectError = error{
    Timeout,
    Rejected,
    Unexpected,
};

pub const GattError = error{
    AttError,
    Timeout,
    Disconnected,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        // scan
        _ = @as(*const fn (*Impl, ScanConfig) ScanError!void, &Impl.startScanning);
        _ = @as(*const fn (*Impl) void, &Impl.stopScanning);

        // connect
        _ = @as(*const fn (*Impl, BdAddr, AddrType, ConnParams) ConnectError!void, &Impl.connect);
        _ = @as(*const fn (*Impl, u16) void, &Impl.disconnect);

        // discovery
        _ = @as(*const fn (*Impl, u16, []DiscoveredService) GattError!usize, &Impl.discoverServices);
        _ = @as(*const fn (*Impl, u16, u16, u16, []DiscoveredChar) GattError!usize, &Impl.discoverChars);

        // GATT client
        _ = @as(*const fn (*Impl, u16, u16, []u8) GattError!usize, &Impl.gattRead);
        _ = @as(*const fn (*Impl, u16, u16, []const u8) GattError!void, &Impl.gattWrite);
        _ = @as(*const fn (*Impl, u16, u16, []const u8) GattError!void, &Impl.gattWriteCmd);
        _ = @as(*const fn (*Impl, u16, u16) GattError!void, &Impl.subscribe);
        _ = @as(*const fn (*Impl, u16, u16) GattError!void, &Impl.unsubscribe);

        // state
        _ = @as(*const fn (*const Impl) State, &Impl.getState);

        // event
        _ = @as(*const fn (*Impl, ?*anyopaque, *const fn (?*anyopaque, CentralEvent) void) void, &Impl.addEventHook);

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

        // -- scan --

        pub fn startScanning(self: Self, config: ScanConfig) ScanError!void {
            return self.driver.startScanning(config);
        }

        pub fn stopScanning(self: Self) void {
            self.driver.stopScanning();
        }

        // -- connect --

        pub fn connect(self: Self, addr: BdAddr, addr_type: AddrType, params: ConnParams) ConnectError!void {
            return self.driver.connect(addr, addr_type, params);
        }

        pub fn disconnect(self: Self, conn_handle: u16) void {
            self.driver.disconnect(conn_handle);
        }

        // -- discovery --

        pub fn discoverServices(self: Self, conn_handle: u16, out: []DiscoveredService) GattError!usize {
            return self.driver.discoverServices(conn_handle, out);
        }

        pub fn discoverChars(self: Self, conn_handle: u16, start_handle: u16, end_handle: u16, out: []DiscoveredChar) GattError!usize {
            return self.driver.discoverChars(conn_handle, start_handle, end_handle, out);
        }

        // -- GATT client --

        pub fn gattRead(self: Self, conn_handle: u16, attr_handle: u16, out: []u8) GattError!usize {
            return self.driver.gattRead(conn_handle, attr_handle, out);
        }

        pub fn gattWrite(self: Self, conn_handle: u16, attr_handle: u16, data: []const u8) GattError!void {
            return self.driver.gattWrite(conn_handle, attr_handle, data);
        }

        pub fn gattWriteCmd(self: Self, conn_handle: u16, attr_handle: u16, data: []const u8) GattError!void {
            return self.driver.gattWriteCmd(conn_handle, attr_handle, data);
        }

        pub fn subscribe(self: Self, conn_handle: u16, cccd_handle: u16) GattError!void {
            return self.driver.subscribe(conn_handle, cccd_handle);
        }

        pub fn unsubscribe(self: Self, conn_handle: u16, cccd_handle: u16) GattError!void {
            return self.driver.unsubscribe(conn_handle, cccd_handle);
        }

        // -- state --

        pub fn getState(self: Self) State {
            return self.driver.getState();
        }

        // -- event --

        pub fn addEventHook(self: Self, ctx: ?*anyopaque, call: *const fn (?*anyopaque, CentralEvent) void) void {
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
