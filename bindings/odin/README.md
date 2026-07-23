# Odin FFI Bindings for libseatuya

Runtime-loaded binding using `dlopen`/`LoadLibrary`. The `load()` function checks `SEATUYA_LIB` first, then falls back to the platform default (`libseatuya.so`, `libseatuya.dylib`, or `seatuya.dll`). Requires libseatuya installed.

```odin
lib, ok := seatuya.load()
dev := lib.tuya_alloc("3.4")

lib.tuya_turn_on(dev, 1)
lib.tuya_destroy(dev)
```
