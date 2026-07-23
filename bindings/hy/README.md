# Hy Lisp FFI Bindings for libseatuya

Hy compiles to Python AST, so it inherits Python's `ctypes` directly.
This is a thin Lisp-syntax wrapper — identical semantics, much nicer
syntax.

## Prerequisites
- [Hy](https://hylang.org/) (`pip install hy`)
- libseatuya installed

## Usage
```hy
(import seatuya)
(setv dev (seatuya.create id "192.168.1.100" key "3.4"))
(print (seatuya.turn-on dev 1))
(seatuya.destroy dev)
```

Run: `hy example.hy`
