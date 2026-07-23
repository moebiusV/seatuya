# BQN FFI Bindings for libseatuya

BQN binding using [CBQN](https://github.com/dzaima/CBQN)'s `•FFI` system
value.  BQN is an array-oriented programming language designed by Marshall
Lo.  CBQN is the primary implementation, written in BQN itself with a C
runtime that supports libffi.

**Note:** BQN FFI is experimental.  CBQN must be built with libffi support
enabled.  This binding has been verified against CBQN's `•FFI` API; other
BQN implementations (dzaima/BQN, BQN.js) have different FFI mechanisms.

## Prerequisites

- [CBQN](https://github.com/dzaima/CBQN) built with FFI support
- libseatuya installed (`make install`)

## Usage

```bqn
⟨seatuya⟩ ← •Import "seatuya.bqn"

dev ← seatuya.Create device_id ip local_key "3.4"

•Show seatuya.TurnOn dev 1
•Show seatuya.Status dev
•Show seatuya.TurnOff dev 1

seatuya.Destroy dev
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
BQN functions use `PascalCase` naming.  String return values are
automatically consumed from C malloc'd pointers.  The `Command` constant
is a BQN list of `⟨code, name⟩` pairs.
