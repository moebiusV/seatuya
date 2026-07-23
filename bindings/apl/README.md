# Dyalog APL FFI Bindings for libseatuya

Dyalog APL binding using `⎕NA` (Name Association) for C interop.
Each function is declared with its C signature and returns a
namespace of callable APL functions.

## Prerequisites
- Dyalog APL 18.0+
- libseatuya installed

## Usage
```apl
dev←seatuya.create deviceId ip localKey '3.4'
⎕←dev seatuya.turnOn 1
seatuya.destroy dev
```
Run: `dyalog example.apl`

**Note:** Dyalog APL's `⎕NA` syntax varies between versions.
Adjust the function signatures if using an older version.
