# Vala C FFI Bindings for libseatuya

Pure Vala binding using `[CCode]` attributes for C interop, compiled to
native code via the Vala-to-C compiler.

## Prerequisites

- Vala 0.56+ (with GLib 2.0)
- libseatuya installed (`make install`)

## Build and run

On Linux:

```sh
valac --pkg glib-2.0 \
  -X -Wl,--unresolved-symbols=ignore-in-object-files \
  -o example example.vala seatuya.vala
./example
```

On macOS:

```sh
valac --pkg glib-2.0 \
  -X -Wl,-undefined,dynamic_lookup \
  -o example example.vala seatuya.vala
./example
```

## Usage

```vala
var dev = Seatuya.create(deviceId, "192.168.1.100", localKey, "3.4");
print("%s\n", Seatuya.turn_on(dev, 1));
print("%s\n", Seatuya.status(dev));
Seatuya.destroy(dev);
```

## API

See the [seatuya(3)](../../seatuya.3) manpage.  The `Seatuya` namespace
exposes every C function as a Vala function with snake_case naming.

### Library loading

At startup, the binding calls `dlopen()` to load `libseatuya.so` (or
`.dylib` on macOS, `.dll` on Windows).  Set the `SEATUYA_LIB` environment
variable to override the library path.

Because the library is loaded at runtime (not linked at compile time), the
linker flags `--unresolved-symbols=ignore-in-object-files` (Linux) or
`-undefined,dynamic_lookup` (macOS) are required.

### String management

Malloc'd C strings returned by `set_value_*`, `turn_on/off`, `status`,
`heartbeat`, `decode_message`, and `generate_payload` are automatically
copied to Vala strings and freed via `tuya_free_string`.  Internal pointers
returned by `get_device_id`, `get_local_key`, and `get_ip` are exposed
directly (no copy, no free).

### Boolean conversion

C functions returning C `bool` (`_Bool`) use the C convention of returning
`int` (0/1) in the raw binding, then are wrapped to return native Vala
`bool` values.
