# Janet FFI Bindings for libseatuya

Pure Janet binding using the built-in `ffi/` module.  The `ffi/defbind`
macro declares every C function, and convenience wrappers handle string
ownership (malloc'd C strings are copied to Janet strings and freed).

## Prerequisites

- Janet 1.28+
- libseatuya installed (`make install`)

## Usage

```janet
(import seatuya)

(def dev (seatuya/create device-id "192.168.1.100" local-key "3.4"))

# Type-aware setter
(print (seatuya/set-value dev 1 true))       # boolean
(print (seatuya/set-value dev 2 25))         # integer
(print (seatuya/set-value dev 3 "hello"))    # string
(print (seatuya/set-value dev 4 23.5))       # float

# Convenience wrappers
(print (seatuya/turn-on dev 1))
(print (seatuya/status dev))
(print (seatuya/turn-off dev 1))

(seatuya/destroy dev)
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
Every C function is available with Janet-idiomatic kebab-case naming.
Constants are global defs (`CMD_CONTROL`, `PROTO_V34`, etc.).
