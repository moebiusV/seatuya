// example.zig -- demonstrate libseatuya via Zig FFI
//
// Build: zig build-exe example.zig -I. -lc
// Run:   ./example

const std = @import("std");
const seatuya = @import("seatuya.zig");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const device_id = std.process.getEnvVarOwned(alloc, "TUYA_DEVICE_ID") catch "0123456789abcdef01234567";
    defer if (device_id.len > 0 and @as(?[]const u8, device_id) != null and device_id.ptr != @as([*]const u8, @ptrCast("0123456789abcdef01234567"))) {} // owned or literal, safe to free only if owned.
    // Simplified: use a buffer approach
    const dev_id = if (std.process.getEnvVarOwned(alloc, "TUYA_DEVICE_ID")) |v| blk: {
        break :blk v;
    } else |_| "0123456789abcdef01234567";
    const local_key = if (std.process.getEnvVarOwned(alloc, "TUYA_LOCAL_KEY")) |v| blk: {
        break :blk v;
    } else |_| "0123456789abcdef";
    const ip = if (std.process.getEnvVarOwned(alloc, "TUYA_IP")) |v| blk: {
        break :blk v;
    } else |_| "192.168.1.100";
    const ver = if (std.process.getEnvVarOwned(alloc, "TUYA_VERSION")) |v| blk: {
        break :blk v;
    } else |_| "3.4";

    defer {
        if (dev_id.ptr != @as([*]const u8, @ptrCast("0123456789abcdef01234567"))) alloc.free(dev_id);
        if (local_key.ptr != @as([*]const u8, @ptrCast("0123456789abcdef"))) alloc.free(local_key);
        if (ip.ptr != @as([*]const u8, @ptrCast("192.168.1.100"))) alloc.free(ip);
        if (ver.ptr != @as([*]const u8, @ptrCast("3.4"))) alloc.free(ver);
    }

    const lib = seatuya.Library.open();
    std.debug.print("seatuya version: {s}\n", .{lib.version() orelse "unknown"});

    // Allocate a device handle for incremental setup
    const dev = lib.alloc(ver) orelse {
        std.debug.print("ERROR: Could not create device handle\n", .{});
        std.process.exit(1);
    };
    defer lib.destroy(dev);

    lib.setCredentials(dev, dev_id, local_key);
    _ = lib.connect(dev, ip);

    std.debug.print("Connected: {}\n", .{lib.isConnected(dev)});
    std.debug.print("turn_on: {s}\n", .{lib.turnOn(dev, 1) orelse "<null>"});
    std.debug.print("status: {s}\n", .{lib.status(dev) orelse "<null>"});
    std.debug.print("turn_off: {s}\n", .{lib.turnOff(dev, 1) orelse "<null>"});

    // Demonstrates type-aware set_value dispatcher
    _ = lib.setValue(dev, 1, true); // bool
    _ = lib.setValue(dev, 2, @as(i32, 25)); // int
    _ = lib.setValue(dev, 3, @as(f64, 23.5)); // float

    std.debug.print("Done.\n", .{});
}
