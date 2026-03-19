//! Websim stub — OtaBackend (placeholder, not a real implementation).

const ota_contract = @import("../../runtime/ota_backend.zig");

pub const OtaBackend = struct {
    pub fn begin(_: *OtaBackend, _: u32) ota_contract.Error!void {
        return error.InitFailed;
    }
    pub fn write(_: *OtaBackend, _: []const u8) ota_contract.Error!void {
        return error.WriteFailed;
    }
    pub fn finalize(_: *OtaBackend) ota_contract.Error!void {
        return error.FinalizeFailed;
    }
    pub fn abort(_: *OtaBackend) void {}
    pub fn confirm(_: *OtaBackend) ota_contract.Error!void {
        return error.ConfirmFailed;
    }
    pub fn rollback(_: *OtaBackend) ota_contract.Error!void {
        return error.RollbackFailed;
    }
    pub fn getState(_: *OtaBackend) ota_contract.State {
        return .unknown;
    }
};
