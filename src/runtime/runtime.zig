//! Runtime suite contract — aggregates all runtime component contracts.

const time = @import("time.zig");
const log = @import("log.zig");
const rng = @import("rng.zig");
const mutex = @import("sync/mutex.zig");
const condition = @import("sync/condition.zig");
const notify = @import("sync/notify.zig");
const thread = @import("thread.zig");
const system = @import("system.zig");
const fs = @import("fs.zig");
const channel_factory = @import("channel_factory.zig");
const tcpip = @import("tcpip.zig");
const netif = @import("netif.zig");
const ota_backend = @import("ota_backend.zig");
const crypto_suite = @import("crypto/suite.zig");

const Seal = struct {};

pub fn Make(comptime Impl: type) type {
    const Time = time.Make(Impl.Time);
    const Log = log.Make(Impl.Log);
    const Rng = rng.Make(Impl.Rng);
    const Mutex = mutex.Make(Impl.Mutex);
    const Condition = condition.Make(Impl.Condition, Impl.Mutex);
    const Notify = notify.Make(Impl.Notify);
    const Thread = thread.Make(Impl.Thread);
    const System = system.Make(Impl.System);
    const Fs = fs.Make(Impl.Fs);
    const ChannelFactory = channel_factory.Make(Impl.ChannelFactory);
    const TcpIp = tcpip.Make(Impl.TcpIp);
    const Netif = netif.Make(Impl.Netif);
    const OtaBackend = ota_backend.Make(Impl.OtaBackend);
    const Crypto = crypto_suite.Make(Impl.Crypto);

    return struct {
        pub const seal: Seal = .{};

        time_inst: Time,
        log_inst: Log,
        rng_inst: Rng,
        mutex_inst: Mutex,
        condition_inst: Condition,
        notify_inst: Notify,
        system_inst: System,
        fs_inst: Fs,
        ota_backend_inst: OtaBackend,
        crypto_inst: Crypto,
        thread_inst: Thread,
        tcpip_inst: TcpIp,
        netif_inst: Netif,

        const Self = @This();

        pub fn init(
            time_impl: *Impl.Time,
            log_impl: *Impl.Log,
            rng_impl: *Impl.Rng,
            mutex_impl: *Impl.Mutex,
            condition_impl: *Impl.Condition,
            notify_impl: *Impl.Notify,
            system_impl: *Impl.System,
            fs_impl: *Impl.Fs,
            ota_backend_impl: *Impl.OtaBackend,
            crypto: Crypto,
            thread_impl: *Impl.Thread,
            tcpip_impl: *Impl.TcpIp,
            netif_impl: *Impl.Netif,
        ) Self {
            return .{
                .time_inst = Time.init(time_impl),
                .log_inst = Log.init(log_impl),
                .rng_inst = Rng.init(rng_impl),
                .mutex_inst = Mutex.init(mutex_impl),
                .condition_inst = Condition.init(condition_impl),
                .notify_inst = Notify.init(notify_impl),
                .system_inst = System.init(system_impl),
                .fs_inst = Fs.init(fs_impl),
                .ota_backend_inst = OtaBackend.init(ota_backend_impl),
                .crypto_inst = crypto,
                .thread_inst = Thread.init(thread_impl),
                .tcpip_inst = TcpIp.init(tcpip_impl),
                .netif_inst = Netif.init(netif_impl),
            };
        }

        pub fn deinit(self: *Self) void {
            self.crypto_inst.deinit();
            self.ota_backend_inst.deinit();
            self.fs_inst.deinit();
            self.system_inst.deinit();
            self.notify_inst.deinit();
            self.condition_inst.deinit();
            self.mutex_inst.deinit();
            self.rng_inst.deinit();
            self.log_inst.deinit();
            self.time_inst.deinit();
            self.thread_inst.deinit();
            self.tcpip_inst.deinit();
            self.netif_inst.deinit();
        }

        pub fn Channel(comptime T: type) type {
            return ChannelFactory.Make(T).Channel(T);
        }
    };
}

/// Check whether T has been sealed via Make().
pub fn is(comptime T: type) bool {
    return @hasDecl(T, "seal") and @TypeOf(T.seal) == Seal;
}
