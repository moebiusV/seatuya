# Terra FFI Bindings for libseatuya

Terra is a low-level language embedded in Lua, built on LuaJIT's FFI.
This binding uses LuaJIT's `ffi.cdef` for debug-mode C type checking
and exposes both Lua-friendly wrappers and Terra-compiled functions.

## Prerequisites
- [Terra](https://terralang.org/)
- libseatuya installed

## Usage
```lua
local seatuya = require("seatuya")
local dev = seatuya.create(id, "192.168.1.100", key, "3.4")
print(seatuya.turn_on(dev, 1))
seatuya.destroy(dev)
```
