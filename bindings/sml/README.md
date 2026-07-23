# Standard ML (MLton) FFI Bindings for libseatuya

MLton FFI binding using `_import` for C function declarations.
The opaque pointer is represented as an ML `word`.

## Prerequisites
- MLton compiler
- libseatuya installed

## Build
```sh
mlton -link-opt -lseatuya seatuya.sml example.sml
```

## Usage
```sml
val dev = Seatuya.create (did, ip, key, "3.4")
print (Seatuya.turnOn (dev, 1) ^ "\n")
Seatuya.destroy dev
```
