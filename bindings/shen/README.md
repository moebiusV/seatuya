Shen FFI bindings for libseatuya.  Uses Shen's `foreign` macro which delegates to the host Common Lisp's FFI (SBCL, CCL, or ECL).  Loading the shared library is host-specific: on SBCL use `(seatuya:load "libseatuya.so")`, on CCL use `(cd "(ccl:open-shared-library \"libseatuya.so\")")`.  Malloc'd C strings from `tuya_status` and friends are auto-converted to Shen strings but the original C memory is leaked (a negligible amount in typical usage).

```
shen --load seatuya.shen --eval '(load "example.shen")'
```
