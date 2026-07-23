Dyalog APL FFI bindings for libseatuya.  Uses `⎕NA` (Name Association) for direct C function calls with configurable library path (respects `SEATUYA_LIB` env var).  Malloc'd C strings from `Status`, `TurnOn` etc. are auto-converted to APL character vectors using the `T` result type; the original C memory is leaked (Dyalog's `⎕NA` does not expose the raw pointer after conversion -- negligible in typical usage).  Requires Dyalog APL 18.0 or later.

```
dyalog example.apl
```
