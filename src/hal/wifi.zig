//! HAL WiFi Contract
//!
//! WiFi network interface: connection management, status queries,
//! scanning, power/radio config, AP mode, and L2 frame IO for netstack.
//!
//! Impl must provide all methods listed in the Make() comptime checks.

const serial = @import("serial.zig");

pub const PollFd = serial.PollFd;
pub const ReadError = serial.ReadError;
pub const WriteError = serial.WriteError;

pub const IpAddress = [4]u8;
pub const Mac = [6]u8;

pub const Status = enum {
    disconnected,
    connecting,
    connected,
    failed,
    ap_running,
};

pub const DisconnectReason = enum {
    user_request,
    auth_failed,
    ap_not_found,
    connection_lost,
    unknown,
};

pub const FailReason = enum {
    timeout,
    auth_failed,
    ap_not_found,
    dhcp_failed,
    unknown,
};

pub const AuthMode = enum {
    open,
    wep,
    wpa_psk,
    wpa2_psk,
    wpa_wpa2_psk,
    wpa3_psk,
    wpa2_wpa3_psk,
    wpa2_enterprise,
    wpa3_enterprise,
};

pub const PhyMode = enum {
    @"11b",
    @"11g",
    @"11n",
    @"11a",
    @"11ac",
    @"11ax",
};

pub const ScanType = enum {
    active,
    passive,
};

pub const ConnectConfig = struct {
    ssid: []const u8,
    password: []const u8 = "",
    channel_hint: u8 = 0,
    bssid: ?Mac = null,
    auth_mode: ?AuthMode = null,
    timeout_ms: u32 = 30_000,
};

pub const ScanConfig = struct {
    ssid: ?[]const u8 = null,
    bssid: ?Mac = null,
    channel: u8 = 0,
    show_hidden: bool = false,
    scan_type: ScanType = .active,
};

pub const ApInfo = struct {
    ssid: [32]u8,
    ssid_len: u8,
    bssid: Mac,
    channel: u8,
    rssi: i8,
    auth_mode: AuthMode,

    pub fn getSsid(self: *const ApInfo) []const u8 {
        return self.ssid[0..self.ssid_len];
    }
};

pub const PowerSaveMode = enum {
    none,
    min_modem,
    max_modem,
};

pub const ApConfig = struct {
    ssid: []const u8,
    password: []const u8 = "",
    channel: u8 = 1,
    auth_mode: AuthMode = .wpa2_psk,
    max_connections: u8 = 4,
    hidden: bool = false,
};

pub const StaInfo = struct {
    mac: Mac,
    rssi: i8,
};

pub const WifiEvent = union(enum) {
    connected: void,
    disconnected: DisconnectReason,
    connection_failed: FailReason,
    scan_result: ApInfo,
    scan_done: bool,
    rssi_low: i8,
    ap_sta_connected: StaInfo,
    ap_sta_disconnected: StaInfo,
};

pub const ConnectError = error{
    InvalidConfig,
    AuthFailed,
    Timeout,
    Unexpected,
};

pub const ScanError = error{
    Busy,
    Unexpected,
};

pub const ApError = error{
    InvalidConfig,
    Unexpected,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        // connection
        _ = @as(*const fn (*Impl, ConnectConfig) ConnectError!void, &Impl.connect);
        _ = @as(*const fn (*Impl) void, &Impl.disconnect);
        _ = @as(*const fn (*const Impl) Status, &Impl.status);

        // event
        _ = @as(*const fn (*Impl, ?*anyopaque, *const fn (?*anyopaque, WifiEvent) void) void, &Impl.addEventHook);

        // info
        _ = @as(*const fn (*const Impl) ?i8, &Impl.getRssi);
        _ = @as(*const fn (*const Impl) ?Mac, &Impl.getMac);
        _ = @as(*const fn (*const Impl) ?u8, &Impl.getChannel);

        // scan
        _ = @as(*const fn (*Impl, ScanConfig) ScanError!void, &Impl.scanStart);

        // power
        _ = @as(*const fn (*Impl, PowerSaveMode) void, &Impl.setPowerSave);
        _ = @as(*const fn (*Impl, i8) void, &Impl.setTxPower);

        // AP
        _ = @as(*const fn (*Impl, ApConfig) ApError!void, &Impl.startAp);
        _ = @as(*const fn (*Impl) void, &Impl.stopAp);

        // L2 IO
        _ = @as(*const fn (*Impl, []u8) ReadError!usize, &Impl.read);
        _ = @as(*const fn (*Impl, []const u8) WriteError!usize, &Impl.write);
        _ = @as(*const fn (*Impl, PollFd, i32) PollFd, &Impl.poll);
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

        // -- connection --

        pub fn connect(self: Self, config: ConnectConfig) ConnectError!void {
            return self.driver.connect(config);
        }

        pub fn disconnect(self: Self) void {
            self.driver.disconnect();
        }

        pub fn status(self: Self) Status {
            return self.driver.status();
        }

        // -- info --

        pub fn getRssi(self: Self) ?i8 {
            return self.driver.getRssi();
        }

        pub fn getMac(self: Self) ?Mac {
            return self.driver.getMac();
        }

        pub fn getChannel(self: Self) ?u8 {
            return self.driver.getChannel();
        }

        // -- scan --

        pub fn scanStart(self: Self, config: ScanConfig) ScanError!void {
            return self.driver.scanStart(config);
        }

        // -- power --

        pub fn setPowerSave(self: Self, mode: PowerSaveMode) void {
            self.driver.setPowerSave(mode);
        }

        pub fn setTxPower(self: Self, power: i8) void {
            self.driver.setTxPower(power);
        }

        // -- AP --

        pub fn startAp(self: Self, config: ApConfig) ApError!void {
            return self.driver.startAp(config);
        }

        pub fn stopAp(self: Self) void {
            self.driver.stopAp();
        }

        pub fn addEventHook(self: Self, ctx: ?*anyopaque, call: *const fn (?*anyopaque, WifiEvent) void) void {
            self.driver.addEventHook(ctx, call);
        }

        // -- L2 IO --
        pub fn read(self: Self, buf: []u8) ReadError!usize {
            return self.driver.read(buf);
        }

        pub fn write(self: Self, data: []const u8) WriteError!usize {
            return self.driver.write(data);
        }

        pub fn poll(self: Self, request: PollFd, timeout_ms: i32) PollFd {
            return self.driver.poll(request, timeout_ms);
        }
    };
}

pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
