//! HAL Cellular Modem Contract
//!
//! Full cellular modem interface covering device identity, SIM management,
//! network registration, data connection (PDP/APN), radio configuration,
//! SMS, power management, and serial IO for PPP netstack integration.
//!
//! Impl must provide all methods listed in the Make() comptime checks.

const serial = @import("serial.zig");

pub const PollFd = serial.PollFd;
pub const ReadError = serial.ReadError;
pub const WriteError = serial.WriteError;

pub const InfoError = error{
    NotAvailable,
    Unexpected,
};

// -- SIM --

pub const SimStatus = enum {
    not_inserted,
    pin_required,
    puk_required,
    ready,
    error_state,
};

pub const PinError = error{
    WrongPin,
    Blocked,
    Unexpected,
};

// -- network registration --

pub const RegStatus = enum {
    not_registered,
    searching,
    registered_home,
    registered_roaming,
    denied,
};

pub const NetworkType = enum {
    gsm,
    gprs,
    edge,
    umts,
    hspa,
    lte,
    lte_cat_m,
    lte_cat_nb,
    nr,
};

pub const NetworkMode = enum {
    auto,
    gsm_only,
    umts_only,
    lte_only,
    nr_only,
    lte_nb_only,
};

// -- data connection --

pub const ApnConfig = struct {
    cid: u8 = 1,
    apn: []const u8,
    username: []const u8 = "",
    password: []const u8 = "",
    pdp_type: PdpType = .ipv4,
};

pub const PdpType = enum {
    ipv4,
    ipv6,
    ipv4v6,
};

pub const DataStatus = enum {
    disconnected,
    connecting,
    connected,
};

pub const ConnectError = error{
    InvalidConfig,
    NoSim,
    NotRegistered,
    Timeout,
    Unexpected,
};

// -- SMS --

pub const SmsEncoding = enum {
    gsm7,
    ucs2,
};

pub const SmsMessage = struct {
    sender: [20]u8 = undefined,
    sender_len: u8 = 0,
    body: [160]u8 = undefined,
    body_len: u8 = 0,
    encoding: SmsEncoding = .gsm7,

    pub fn getSender(self: *const SmsMessage) []const u8 {
        return self.sender[0..self.sender_len];
    }

    pub fn getBody(self: *const SmsMessage) []const u8 {
        return self.body[0..self.body_len];
    }
};

pub const SmsError = error{
    NotReady,
    SendFailed,
    Unexpected,
};

// -- power --

pub const PowerMode = enum {
    full,
    airplane,
    minimum,
};

pub const SleepConfig = struct {
    psm_enabled: bool = false,
    edrx_enabled: bool = false,
    edrx_value: ?u8 = null,
};

// -- events --

pub const DisconnectReason = enum {
    user_request,
    network_lost,
    sim_error,
    unknown,
};

pub const ModemEvent = union(enum) {
    data_connected: void,
    data_disconnected: DisconnectReason,
    reg_changed: RegStatus,
    sim_changed: SimStatus,
    sms_received: SmsMessage,
};

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    comptime {
        // device info
        _ = @as(*const fn (*const Impl, []u8) InfoError!usize, &Impl.getImei);
        _ = @as(*const fn (*const Impl, []u8) InfoError!usize, &Impl.getModel);
        _ = @as(*const fn (*const Impl, []u8) InfoError!usize, &Impl.getFirmwareVersion);

        // SIM
        _ = @as(*const fn (*const Impl) SimStatus, &Impl.getSimStatus);
        _ = @as(*const fn (*const Impl, []u8) InfoError!usize, &Impl.getImsi);
        _ = @as(*const fn (*const Impl, []u8) InfoError!usize, &Impl.getIccid);
        _ = @as(*const fn (*Impl, []const u8) PinError!void, &Impl.unlockPin);

        // network registration
        _ = @as(*const fn (*const Impl) RegStatus, &Impl.getRegStatus);
        _ = @as(*const fn (*const Impl) ?NetworkType, &Impl.getNetworkType);
        _ = @as(*const fn (*const Impl, []u8) InfoError!usize, &Impl.getOperator);
        _ = @as(*const fn (*const Impl) ?i8, &Impl.getRssi);

        // radio config
        _ = @as(*const fn (*Impl, NetworkMode) void, &Impl.setNetworkMode);
        _ = @as(*const fn (*const Impl) NetworkMode, &Impl.getNetworkMode);

        // data connection
        _ = @as(*const fn (*Impl, ApnConfig) void, &Impl.setApn);
        _ = @as(*const fn (*Impl, u8) ConnectError!void, &Impl.activate);
        _ = @as(*const fn (*Impl, u8) void, &Impl.deactivate);
        _ = @as(*const fn (*const Impl) DataStatus, &Impl.getDataStatus);

        // SMS
        _ = @as(*const fn (*Impl, []const u8, []const u8) SmsError!void, &Impl.sendSms);

        // power
        _ = @as(*const fn (*Impl, PowerMode) void, &Impl.setPowerMode);
        _ = @as(*const fn (*const Impl) PowerMode, &Impl.getPowerMode);
        _ = @as(*const fn (*Impl, SleepConfig) void, &Impl.setSleep);
        _ = @as(*const fn (*Impl) void, &Impl.reset);

        // event
        _ = @as(*const fn (*Impl, ?*anyopaque, *const fn (?*anyopaque, ModemEvent) void) void, &Impl.addEventHook);

        // serial IO (for PPP)
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

        // -- device info --

        pub fn getImei(self: Self, buf: []u8) InfoError!usize {
            return self.driver.getImei(buf);
        }

        pub fn getModel(self: Self, buf: []u8) InfoError!usize {
            return self.driver.getModel(buf);
        }

        pub fn getFirmwareVersion(self: Self, buf: []u8) InfoError!usize {
            return self.driver.getFirmwareVersion(buf);
        }

        // -- SIM --

        pub fn getSimStatus(self: Self) SimStatus {
            return self.driver.getSimStatus();
        }

        pub fn getImsi(self: Self, buf: []u8) InfoError!usize {
            return self.driver.getImsi(buf);
        }

        pub fn getIccid(self: Self, buf: []u8) InfoError!usize {
            return self.driver.getIccid(buf);
        }

        pub fn unlockPin(self: Self, pin: []const u8) PinError!void {
            return self.driver.unlockPin(pin);
        }

        // -- network registration --

        pub fn getRegStatus(self: Self) RegStatus {
            return self.driver.getRegStatus();
        }

        pub fn getNetworkType(self: Self) ?NetworkType {
            return self.driver.getNetworkType();
        }

        pub fn getOperator(self: Self, buf: []u8) InfoError!usize {
            return self.driver.getOperator(buf);
        }

        pub fn getRssi(self: Self) ?i8 {
            return self.driver.getRssi();
        }

        // -- radio config --

        pub fn setNetworkMode(self: Self, mode: NetworkMode) void {
            self.driver.setNetworkMode(mode);
        }

        pub fn getNetworkMode(self: Self) NetworkMode {
            return self.driver.getNetworkMode();
        }

        // -- data connection --

        pub fn setApn(self: Self, config: ApnConfig) void {
            self.driver.setApn(config);
        }

        pub fn activate(self: Self, cid: u8) ConnectError!void {
            return self.driver.activate(cid);
        }

        pub fn deactivate(self: Self, cid: u8) void {
            self.driver.deactivate(cid);
        }

        pub fn getDataStatus(self: Self) DataStatus {
            return self.driver.getDataStatus();
        }

        // -- SMS --

        pub fn sendSms(self: Self, number: []const u8, text: []const u8) SmsError!void {
            return self.driver.sendSms(number, text);
        }

        // -- power --

        pub fn setPowerMode(self: Self, mode: PowerMode) void {
            self.driver.setPowerMode(mode);
        }

        pub fn getPowerMode(self: Self) PowerMode {
            return self.driver.getPowerMode();
        }

        pub fn setSleep(self: Self, config: SleepConfig) void {
            self.driver.setSleep(config);
        }

        pub fn reset(self: Self) void {
            self.driver.reset();
        }

        // -- event --

        pub fn addEventHook(self: Self, ctx: ?*anyopaque, call: *const fn (?*anyopaque, ModemEvent) void) void {
            self.driver.addEventHook(ctx, call);
        }

        // -- serial IO (for PPP) --

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
