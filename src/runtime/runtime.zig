const std_lib = @import("std");

pub const errors = @import("errors.zig");

pub const sync_mod = @import("sync.zig");
pub const time_mod = @import("time.zig");
pub const thread_mod = @import("thread.zig");
pub const system_mod = @import("system.zig");
pub const io_mod = @import("io.zig");
pub const socket_mod = @import("socket.zig");
pub const fs_mod = @import("fs.zig");
pub const log_mod = @import("log.zig");
pub const rng_mod = @import("rng.zig");
pub const netif_mod = @import("netif.zig");
pub const ota_backend_mod = @import("ota_backend.zig");
pub const crypto_mod = @import("crypto/root.zig");
pub const std_impl = @import("std/root.zig");

// Backward-compat aliases for direct module access.
pub const sync = sync_mod;
pub const time = time_mod;
pub const thread = thread_mod;
pub const system = system_mod;
pub const io = io_mod;
pub const socket = socket_mod;
pub const fs = fs_mod;
pub const log = log_mod;
pub const rng = rng_mod;
pub const netif = netif_mod;
pub const ota_backend = ota_backend_mod;
pub const crypto = crypto_mod;
pub const std_runtime = std_impl;

/// Build a fixed-shape, instantiable Runtime struct from implementation declarations.
///
/// Usage:
///   const Rt = Runtime(StdRuntimeDecl);
///   var rt = try Rt.init(allocator);
///   defer rt.deinit();
///   rt.time.nowMs();
///   rt.log.info("hello");
///   _ = rt.io.poll(100);
pub fn Runtime(comptime Decl: type) type {
    const Time = time_mod.from(Decl.Time);
    const Log = log_mod.from(Decl.Log);
    const Rng = rng_mod.from(Decl.Rng);
    const Thread = thread_mod.from(Decl.Thread);
    const IO = io_mod.from(Decl.IO);
    const Socket = socket_mod.from(Decl.Socket);
    const Fs = fs_mod.from(Decl.Fs);
    const System = system_mod.from(Decl.System);
    const NetIf = netif_mod.from(Decl.NetIf);
    const OtaBackend = ota_backend_mod.from(Decl.OtaBackend);
    const Crypto = crypto_mod.from(Decl.Crypto);

    return struct {
        const Self = @This();

        // --- service fields (zero-sized, instance methods) ---
        time: Time = .{},
        log: Log = .{},
        rng: Rng = .{},
        system: System = .{},
        netif: NetIf = .{},

        // --- stateful fields ---
        io: IO = undefined,
        fs: Fs = .{},

        // --- type-level declarations (factory / primitive types) ---
        pub const thread = Thread;
        pub const socket = Socket;
        pub const sync = struct {
            pub const Mutex = sync_mod.Mutex(Decl.Mutex);
            pub const Condition = sync_mod.ConditionWithMutex(Decl.Condition, Decl.Mutex);
            pub const Notify = sync_mod.Notify(Decl.Notify);
        };
        pub const ota_backend = OtaBackend;
        pub const crypto = Crypto;

        pub fn init(allocator: std_lib.mem.Allocator) anyerror!Self {
            return Self{
                .io = try IO.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.io.deinit();
        }
    };
}
