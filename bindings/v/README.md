# V FFI Bindings for libseatuya

V bindings using the language's built-in C interop.  C functions are
declared with `fn C.xxx()` and wrapped in type-safe V functions.

## Prerequisites

- V 0.4+
- libseatuya installed (`make install`)

## Build

```bash
# Standard build
v -cflags '-L/usr/local/lib' -run example.v

# Custom library path
SEATUYA_LIB=/opt/lib/libseatuya.so v -cflags "-L$(dirname $SEATUYA_LIB)" -run example.v
```

The `#flag -l seatuya` directive links against libseatuya at compile
time.  Set `SEATUYA_LIB` at build time for a non-standard path.

## Usage

```v
import seatuya

// Device creation (returns optional Device)
dev := seatuya.create(device_id, ip, local_key, "3.4") or { panic(err) }

// High-level operations (return ?string)
seatuya.turn_on(dev, 1) or { 'error' }
println(seatuya.status(dev) or { 'error' })

seatuya.destroy(dev)
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.

All functions that can fail return V optionals (`?T`).  Malloc'd C
strings are consumed into V strings and freed automatically.

### Constants

| Symbol | Description |
|---|---|
| `Command` | `map[string]int` of Tuya command constants |
| `Protocol` | Map of protocol version names to int |
| `SessionState` | Map of session state names to int |
| `SocketState` | Map of socket state names to int |
| `DEFAULT_PORT` | 6668 |
| `BUFSIZE` | 1024 |
