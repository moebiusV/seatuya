# Gauche Scheme FFI Bindings for libseatuya

Pure Gauche binding using the built-in `c-wrapper` module.
Uses `define-cproc` for concise C function declarations.

## Prerequisites
- Gauche 0.9.10+
- libseatuya installed

## Usage
```scheme
(load "./seatuya.scm")
(define dev (seatuya-create did ip key "3.4"))
(print (seatuya-turn-on dev 1))
(seatuya-destroy dev)
```
Run: `gosh example.scm`
