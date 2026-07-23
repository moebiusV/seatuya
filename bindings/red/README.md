Red FFI bindings for libseatuya.  Uses Red's `library!` and `routine!` FFI mechanism for dynamic C interop.  The shared library is loaded at runtime via `load-library`, with `SEATUYA_LIB` env var support.  Malloc'd C strings from `status`, `turn_on` etc. are auto-converted to Red `string!` values; the original C memory is leaked (Red's FFI does not expose the raw pointer after conversion -- negligible in typical usage).  Requires Red 0.6.4 or later with the `library!` runtime.

```
red example.red
```
