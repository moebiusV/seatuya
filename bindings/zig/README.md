# Zig FFI Bindings for libseatuya

Runtime-loaded binding using `std.DynLib`. The `Library.open()` function respects the `SEATUYA_LIB` environment variable for custom library paths. Requires Zig 0.11+ and libseatuya installed.

```zig
const seatuya = @import("seatuya.zig");
const lib = seatuya.Library.open();
const dev = lib.alloc("3.4") orelse return;

_ = lib.turnOn(dev, 1);
lib.destroy(dev);
```
