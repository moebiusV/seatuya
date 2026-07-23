# Lua FFI Bindings for libseatuya

Pure Lua binding using LuaJIT's built-in FFI library.  The `ffi.cdef`
block declares every type and function from `seatuya.h`, so the binding
is always in sync with the C header.  Also works with plain Lua +
[luaffi](https://github.com/jmckaskill/luaffi).

## Prerequisites

- LuaJIT 2.0+ (or Lua 5.1+ with luaffi)
- libseatuya installed (`make install`)

## Usage

```lua
local seatuya = require("seatuya")

local dev = seatuya.create(deviceId, "192.168.1.100", localKey, "3.4")

-- Type-aware setter
print(seatuya.set_value(dev, 1, true))    -- boolean
print(seatuya.set_value(dev, 2, 25))      -- integer
print(seatuya.set_value(dev, 3, "hello")) -- string
print(seatuya.set_value(dev, 4, 23.5))    -- float

-- Convenience wrappers
print(seatuya.turn_on(dev, 1))
print(seatuya.status(dev))
print(seatuya.turn_off(dev, 1))

seatuya.destroy(dev)
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
The module returns a table with every function and constant.  C `bool`
returns are Lua booleans.  Malloc'd C strings are consumed into Lua
strings (automatically freed).
