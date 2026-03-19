//! Websim stub — Netif backend (placeholder, not a real implementation).

const netif_contract = @import("../../runtime/netif.zig");

pub const Netif = struct {
    pub fn addIface(_: *Netif, _: netif_contract.IfaceConfig) netif_contract.Error!netif_contract.IfaceFd {
        return error.Unexpected;
    }
    pub fn removeIface(_: *Netif, _: netif_contract.IfaceFd) void {}
    pub fn setIpConfig(_: *Netif, _: netif_contract.IfaceFd, _: netif_contract.IpConfig) netif_contract.Error!void {
        return error.Unexpected;
    }
    pub fn getIpConfig(_: *const Netif, _: netif_contract.IfaceFd) ?netif_contract.IpConfig {
        return null;
    }
    pub fn getIfaceInfo(_: *const Netif, _: netif_contract.IfaceFd) ?netif_contract.IfaceInfo {
        return null;
    }
    pub fn startDhcpClient(_: *Netif, _: netif_contract.IfaceFd, _: netif_contract.DhcpClientConfig) netif_contract.Error!void {
        return error.Unexpected;
    }
    pub fn stopDhcpClient(_: *Netif, _: netif_contract.IfaceFd) void {}
    pub fn startDhcpServer(_: *Netif, _: netif_contract.IfaceFd, _: netif_contract.DhcpServerConfig) netif_contract.Error!void {
        return error.Unexpected;
    }
    pub fn stopDhcpServer(_: *Netif, _: netif_contract.IfaceFd) void {}
    pub fn ifaceCount(_: *const Netif) u16 {
        return 0;
    }
    pub fn listIfaces(_: *const Netif, _: []netif_contract.IfaceFd) u16 {
        return 0;
    }
    pub fn setDefaultIface(_: *Netif, _: netif_contract.AddressFamily, _: netif_contract.IfaceFd) netif_contract.Error!void {
        return error.Unexpected;
    }
    pub fn defaultIface(_: *const Netif, _: netif_contract.AddressFamily) ?netif_contract.IfaceFd {
        return null;
    }
    pub fn addEventHook(_: *Netif, _: ?*anyopaque, _: *const fn (?*anyopaque, netif_contract.Event) void) void {}
};
