# Eiffel FFI Bindings for libseatuya

Eiffel binding using the `external` keyword for C interop.  Each C
function is declared as a frozen external feature.  The opaque
`tuya_device_t*` is stored as a `POINTER`.

## Prerequisites
- EiffelStudio or GEC (GNU Eiffel Compiler)
- libseatuya installed

## Build
```sh
ec seatuya.e example.e -lseatuya -o example
```

## Usage
```eiffel
create dev.make
dev.handle := dev.create_with(id, "192.168.1.100", key, "3.4")
print(dev.turn_on(1))
dev.destroy
```
