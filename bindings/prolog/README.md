SWI-Prolog FFI bindings for libseatuya.  Uses `library(shlib)` with `dlopen`/`dlsym` for dynamic library loading (with `SEATUYA_LIB` env var support) and `call_shared_function/4` for FFI invocation.  Requires SWI-Prolog 7.x or later.  Malloc'd C strings are auto-consumed by reading the bytes through the raw pointer then calling `tuya_free_string`.

```
swipl -l example.pl -t run
```
