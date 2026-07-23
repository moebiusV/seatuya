# Idris 2 FFI Bindings for libseatuya

Pure Idris 2 binding using `%foreign` for C interop with the Chez Scheme
backend.  A `Seatuya` module exporting every C function with `camelCase`
naming.

## Prerequisites

- Idris 2 (with Chez Scheme backend)
- libseatuya installed (`make install`)

## Build and run

```sh
idris2 -o example Example.idr
LD_LIBRARY_PATH=/usr/local/lib ./build/exec/example
```

## Usage

```idris
import Seatuya

main : IO ()
main = do
  let dev = tuyaCreate deviceId ip localKey ver
  putStrLn $ show (turnOn dev 1)
  putStrLn $ show (status dev)
  tuyaDestroy dev
```

## API

See the [seatuya(3)](../../seatuya.3) manpage.  The `Seatuya` module exposes
every C function as an Idris 2 top-level binding.

### Library loading

On Linux, the `%foreign` declarations load symbols from `libseatuya.so`
automatically.  Set the `SEATUYA_LIB` environment variable to override the
library path, and call `Seatuya.initLib` at the start of your program.
On macOS or Windows, create a symlink so `libseatuya.so` resolves, or use
`initLib` with the full library path.

### String management

Raw C functions that return malloc'd strings (`tuyaStatus`, `tuyaTurnOn`,
etc.) return `Ptr`.  The convenience functions `status`, `turnOn`, `turnOff`,
`heartbeat`, `consumeResponse`, and `setValue` automatically copy the C
string into an Idris `String` and free the original allocation via
`tuya_free_string`.

### Boolean conversion

C functions returning `bool` (as `Int` 0/1) can be converted with `toBool`.

### Type-aware dispatcher

```idris
setValue dev 1 (TBool True)
setValue dev 2 (TInt 42)
setValue dev 3 (TFloat 3.14)
setValue dev 4 (TString "hello")
```

Uses the `TuyaVal` tagged union (`TBool | TInt | TFloat | TString`).
