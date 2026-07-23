# Standard ML (MLton) FFI Bindings for libseatuya

MLton FFI binding using `_import` for C function declarations. The opaque C pointer is represented as an ML `word`. Requires MLton and libseatuya installed. Set `SEATUYA_LIB` at build time for custom library paths (e.g. `mlton -link-opt "-L$(dirname $SEATUYA_LIB)" ...`), or use `LD_LIBRARY_PATH`/`DYLD_LIBRARY_PATH` at runtime.

```sml
val dev = Seatuya.create ("id", "192.168.1.100", "key", "3.4")
print (Seatuya.turnOn (dev, 1) ^ "\n"); Seatuya.destroy dev
```
