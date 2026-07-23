# Haxe C++ FFI Bindings for libseatuya

Pure Haxe binding using `cpp.Lib.load` for the C++ backend.
A `Seatuya` class with static methods wrapping the C API.

## Prerequisites

- Haxe 4.3+ with C++ target
- libseatuya installed (`make install`)

## Build and run

```sh
haxe -main Example -cpp build Example.hx Seatuya.hx
LD_LIBRARY_PATH=/usr/local/lib ./build/Example
```

## Usage

```haxe
import seatuya.Seatuya;

var dev = Seatuya.create(deviceId, "192.168.1.100", localKey, "3.4");
Sys.println(Seatuya.turnOn(dev, 1));
Sys.println(Seatuya.status(dev));
Seatuya.destroy(dev);
```

## API

See the [seatuya(3)](../../seatuya.3) manpage.  The `Seatuya` class exposes
every C function as a static Haxe method with camelCase naming.

### Library loading

`Seatuya` loads `libseatuya.so` via `cpp.Lib.load` at class initialisation.
Set the `SEATUYA_LIB` environment variable to override the library path.
Platform suffixes `.dylib` (macOS) and `.dll` (Windows) are detected
automatically.

### String management

Malloc'd C strings returned by `setValue*`, `turnOn`, `turnOff`, `status`,
`heartbeat`, `decodeMessage`, and `generatePayload` are automatically copied
to Haxe strings and freed via `tuya_free_string`.  Internal pointers returned
by `getDeviceId`, `getLocalKey`, and `getIp` are exposed directly (no copy,
no free).

### Boolean conversion

C functions returning `bool` (`_Bool`) are wrapped to return native Haxe
`Bool` values.
