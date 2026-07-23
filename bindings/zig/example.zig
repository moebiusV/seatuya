// example.zig -- demonstrate libseatuya via Zig FFI
//
// Build: zig build-exe example.zig -I. -lc
// Run:   ./example

const std = @import("std");
const seatuya = @import("seatuya.zig");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const device_id = tryEnv(alloc, "TUYA_DEVICE_ID") orelse "0123456789abcdef01234567";
    const local_key = tryEnv(alloc, "TUYA_LOCAL_KEY") orelse "0123456789abcdef";
    const ip = tryEnv(alloc, "TUYA_IP") orelse "192.168.1.100";
    const ver = tryEnv(alloc, "TUYA_VERSION") orelse "3.4";

    const lib = seatuya.Library.open();
    std.debug.print("seatuya version: {s}\n", .{lib.version() orelse "unknown"});

    // Allocate device handle, set credentials, connect
    const dev = lib.alloc(ver) orelse {
        std.debug.print("ERROR: Could not create device handle\n", .{});
        std.process.exit(1);
    };
    defer lib.destroy(dev);

    lib.setCredentials(dev, device_id, local_key);
    _ = lib.connect(dev, ip);

    std.debug.print("Connected: {}\n", .{lib.isConnected(dev)});
    std.debug.print("turn_on: {s}\n", .{lib.turnOn(dev, 1) orelse "<null>"});
    std.debug.print("status: {s}\n", .{lib.status(dev) orelse "<null>"});
    std.debug.print("turn_off: {s}\n", .{lib.turnOff(dev, 1) orelse "<null>"});

    // Type-aware set_value dispatcher
    _ = lib.setValue(dev, 1, true); // bool
    _ = lib.setValue(dev, 2, @as(i32, 25)); // int
    _ = lib.setValue(dev, 3, @as(f64, 23.5)); // float
    _ = lib.setValue(dev, 4, "hello"); // string

    std.debug.print("Done.\n", .{});
}

fn tryEnv(alloc: std.mem.Allocator, name: []const u8) ?[]const u8 {
    return std.process.getEnvVarOwned(alloc, name) catch null;
}
