# OCaml FFI Bindings for libseatuya

Binding using `ctypes` for type-safe C foreign function declarations with dynamic library loading. Uses `Dl.dlopen` at module init time, respecting the `SEATUYA_LIB` environment variable. Requires `opam install ctypes` and libseatuya installed.

```ocaml
open Seatuya
let dev = create "id" "192.168.1.100" "key" "3.4" in
ignore (turn_on dev 1); destroy dev
```
