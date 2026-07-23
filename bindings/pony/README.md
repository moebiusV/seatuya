Pony FFI bindings for libseatuya.  Uses Pony's `@` FFI annotation for direct C interop via compile-time linking (`use "lib:seatuya"`).  Build with `ponyc --library seatuya --librarypath /usr/local/lib`.  Malloc'd C strings are auto-consumed: the binding returns the raw pointer, copies the data into a Pony `String`, then calls `tuya_free_string`.  Set `SEATUYA_LIB` at load time for custom paths, or use `LD_PRELOAD`.

```
ponyc --library seatuya --librarypath /usr/local/lib .
./example
```
