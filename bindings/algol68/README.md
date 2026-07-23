# Algol 68 FFI Bindings for libseatuya

GCC 16 (released March 2026) includes the `ga68` Algol 68 frontend by
Jose E. Marchesi (Oracle).  Since it uses GCC's code-generation
infrastructure, C functions can be called via `PRAGMA EXTERN "C"`.

**Note:** The `ga68` frontend is new (merged November 2025) and its FFI
syntax is still being documented.  This binding uses the POSIX prelude
extension (`PRAGMA EXTERN`) for C linkage.  Adjust the declarations if
the final ga68 FFI syntax differs from what's shown here.

## Prerequisites
- GCC 16+ with Algol 68 frontend enabled (`--enable-languages=algol`)
- libseatuya installed

## Build
```sh
ga68 -lseatuya seatuya.a68 example.a68 -o example
```

## Usage
```algol
DEV dev := seatuya create(device id, ip, local key, "3.4");
print(seatuya turn on(dev, 1));
seatuya destroy(dev);
```

This binding restores Algol 68 to its rightful place in the IoT ecosystem.
