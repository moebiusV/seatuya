# Gauche Scheme FFI Bindings for libseatuya

Binding using the built-in `c-wrapper` module with `define-cproc` for concise C function declarations. Loads the library via `c-load-library`, respecting the `SEATUYA_LIB` environment variable for custom paths. Requires Gauche 0.9.10+ and libseatuya installed.

```scheme
(load "./seatuya.scm")
(define dev (seatuya-open "id" "192.168.1.100" "key" "3.4"))
(print (seatuya-turn-on dev 1)); (seatuya-destroy dev)
```
