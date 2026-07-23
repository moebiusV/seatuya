# Fennel FFI Bindings for libseatuya

Pure Fennel binding using LuaJIT's built-in FFI library.  The `ffi.cdef`
block declares every type and function from `seatuya.h`, so the binding
is always in sync with the C header.

## Prerequisites

- LuaJIT 2.0+
- [Fennel](https://fennel-lang.org) 1.0+
- libseatuya installed (`make install`)

## Usage

```fennel
(local seatuya (require :seatuya))

(local dev (seatuya.create device-id ip local-key "3.4"))

;; Type-aware setter
(print (seatuya.set-value dev 1 true))       ;; boolean
(print (seatuya.set-value dev 2 25))          ;; integer
(print (seatuya.set-value dev 3 "hello"))    ;; string
(print (seatuya.set-value dev 4 23.5))       ;; float

(print (seatuya.turn-on dev 1))
(print (seatuya.status dev))
(print (seatuya.turn-off dev 1))

(seatuya.destroy dev)
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
The module returns a table with every function and constant.  C `bool`
values are Lua booleans.  Malloc'd C strings are consumed into Lua
strings (automatically freed).

### Library path

Set `SEATUYA_LIB` environment variable to override the library path.
Defaults: `libseatuya.so` (Linux), `libseatuya.dylib` (macOS),
`seatuya.dll` (Windows).

### Constants

| Table | Contents |
|---|---|
| `Command` | 43 Tuya command constants (UDP=0 .. LAN_SET_GW_CHANNEL=252) |
| `Protocol` | V31=0, V33=1, V34=2, V35=3 |
| `SessionState` | INVALID=0, STARTING=1, FINALIZING=2, ESTABLISHED=3 |
| `SocketState` | NO_SUCH_HOST=0 .. RECEIVING=7 |
| `DEFAULT_PORT` | 6668 |
| `BUFSIZE` | 1024 |
