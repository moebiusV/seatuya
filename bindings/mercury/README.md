# Mercury FFI Bindings for libseatuya

Mercury is a logic/functional language that compiles to C.  FFI is via
`:- pragma foreign_proc("C", ...)` with inline C code.  The opaque
pointer is represented as a `c_pointer` with a `pragma foreign_type`.

## Prerequisites
- [Mercury](https://mercurylang.org/) compiler (`mmc`)
- libseatuya installed

## Build
```sh
mmc --make --link-object libseatuya.so example
```

## Usage
```mercury
seatuya.create(Did, Ip, Key, Ver, Dev, !IO),
seatuya.turn_on(Dev, 1, Json, !IO),
seatuya.destroy(Dev, !IO)
```
