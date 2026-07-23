# Wren Bindings for libseatuya

Wren bindings for libseatuya using Wren's foreign class mechanism.
The C host application must register the foreign methods from
`seatuya_wren.c` at VM startup.

## Architecture

```
example.wren
  -> seatuya.wren            (Wren module with `foreign` declarations)
    -> seatuya_wren.c        (C foreign method implementations)
-> seatuya_wren.o            (compiled object file)
      -> libseatuya.so       (C Tuya library)
```

The C file (`seatuya_wren.c`) implements every foreign method declared in
`seatuya.wren`.  A `Device` foreign class holds a `tuya_device_t*` pointer.
Factory static methods (`Device.create`, `Device.alloc`) return a new
`Device` instance or `null` on failure.

## Prerequisites

- Wren (any build with foreign method support, including the official CLI)
- libseatuya installed (`make install`)
- C compiler (gcc or clang)

## Integrating into a Wren host

1. Compile `seatuya_wren.c`:
   ```sh
   cc -c -I/usr/local/include -o seatuya_wren.o seatuya_wren.c
   ```

2. Link into your Wren host program:
   ```sh
   cc -o my_host my_host.c seatuya_wren.o -lseatuya -lwren
   ```

3. Register the foreign bindings in your host code:
   ```c
   config.bindForeignClassFn = seatuyaBindForeignClass;
   config.bindForeignMethodFn = seatuyaBindForeignMethod;
   ```

## Usage

```wren
import "seatuya" for Device

var dev = Device.create("device-id", "192.168.1.100", "local-key", "3.3")
if (dev != null) {
  System.print(dev.turnOn(1))
  System.print(dev.status())
  dev.destroy()
}
```

### Type-aware set_value

```wren
import "seatuya" for Device

var dev = Device.create("id", "ip", "key", "3.3")

// Use the dispatcher function from the module:
// Booleans -> setValueBool, Integers -> setValueInt
// Floats -> setValueFloat, Strings -> setValueString
// (The seatuya.wren module exports a `setValue` Fn for this.)
```

### Constants

```wren
// Command codes are available in the Command map:
Command["CONTROL"]     // 7
Command["DP_QUERY"]    // 10
Command["HEART_BEAT"]  // 9
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
The Wren module maps one-to-one with the C functions.

### String ownership

Malloc'd C strings returned by high-level functions (`status`, `turnOn`,
`setValue*`, etc.) are automatically consumed into Wren strings and freed.
Credential getters return internal `const char*` pointers (no copy, no free
needed).

### Binary data limitation

Low-level functions (`buildMessage`, `decodeMessage`, `send`, `receive`,
`negotiateSessionFinalize`) that accept or return binary data use Wren
strings (which can hold arbitrary bytes).  Input buffers that contain NUL
bytes may be truncated at the first NUL by `strlen()` in the C layer.
For full binary support, use the C API directly or encode your data in a
NUL-free format (e.g. hex or base64) before passing to the Wren binding.
