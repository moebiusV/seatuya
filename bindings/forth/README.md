gforth FFI bindings for libseatuya.  Uses gforth's `c-library` mechanism with embedded C wrappers that perform dynamic library loading via `dlopen`/`dlsym` (respecting `SEATUYA_LIB` env var) and auto-consume malloc'd C strings via `strdup`+`tuya_free_string` in the C wrapper layer.  Requires gforth built with FFI support and a C compiler (gcc/clang) for the embedded C wrappers.

```
gforth example.fs -e "bye"
```
