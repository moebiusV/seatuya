# PicoLisp FFI Bindings for libseatuya

Pure PicoLisp binding using the built-in `(native ...)` function to
call libseatuya directly.  No compilation needed.

## Prerequisites

- PicoLisp 64-bit (pil21 or later)
- libseatuya installed (`make install`)

## Usage

```picolisp
(load "seatuya.l")

# All-in-one: create, connect, and negotiate session
(setq Dev (seatuya~>create DeviceId "192.168.1.100" LocalKey "3.4"))

# Type-aware setter: routes to the correct C function by PicoLisp type
(seatuya~>set-value Dev 1 T)          # boolean → tuya_set_value_bool
(seatuya~>set-value Dev 2 25)         # integer → tuya_set_value_int
(seatuya~>set-value Dev 3 "hello")    # string  → tuya_set_value_string
(seatuya~>set-value Dev 4 23.5)       # float   → tuya_set_value_float

# Convenience wrappers
(seatuya~>turn-on Dev 1)
(prinl (seatuya~>status Dev))
(seatuya~>turn-off Dev 1)

# Teardown
(seatuya~>destroy Dev)
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
Every C function is available through the `seatuya` object (an instance of
`+Seatuya`).  Method names use kebab-case matching the C function name
style.  The `*Cmd...` and `*Proto...` global variables hold the enum
constants.
