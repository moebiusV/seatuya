# Julia FFI Bindings for libseatuya

Pure Julia module using the built-in `ccall` for every function in
libseatuya.  No external dependencies — `ccall` is part of the Julia
language.

## Prerequisites

- Julia 1.8+
- libseatuya installed (`make install`)

## Usage

```julia
using Seatuya

dev = Seatuya.create(device_id, "192.168.1.100", local_key, "3.4")

# Type-aware setter: dispatches to the correct C function by Julia type
println(Seatuya.set_value(dev, 1, true))      # Bool → tuya_set_value_bool
println(Seatuya.set_value(dev, 2, 25))        # Int  → tuya_set_value_int
println(Seatuya.set_value(dev, 3, "hello"))   # String → tuya_set_value_string
println(Seatuya.set_value(dev, 4, 23.5))      # Float64 → tuya_set_value_float

# Convenience wrappers
println(Seatuya.turn_on(dev, 1))
println(Seatuya.status(dev))
println(Seatuya.turn_off(dev, 1))

Seatuya.destroy(dev)
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
The `Seatuya` module exports every function with Julia-idiomatic names
(snake_case).  Enums are Julia `@enum` types.  Malloc'd C strings are
automatically consumed and freed.
