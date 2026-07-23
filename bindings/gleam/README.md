# Gleam Bindings for libseatuya

Gleam bindings for libseatuya calling into the C library through Erlang NIFs.

## Architecture

```
example.gleam
  -> seatuya.gleam         (Gleam module with @external declarations)
    -> seatuya_ffi.erl     (Erlang FFI wrapper: atoms -> binaries, lists -> binaries)
      -> seatuya_nif.erl   (Erlang NIF holder)
        -> seatuya_nif.so  (C shared library compiled from seatuya_nif.c)
          -> libseatuya.so (C Tuya library)
```

The `seatuya.gleam` module declares every function from `seatuya.h` using
`@external(erlang, "seatuya_ffi", ...)`. The Erlang FFI wrapper converts
NIF return values into Gleam-friendly types (`{error, Atom}` to `{error, String}`,
string lists to UTF-8 binaries). The C NIF is the same pattern used by the
[Erlang binding](../erlang/).

## Prerequisites

- Erlang/OTP 24+ (with `erl_nif.h` headers)
- Gleam 0.25+
- libseatuya installed (`make install`)
- C compiler (gcc or clang)

## Building the NIF

```sh
cd bindings/gleam
cc -fPIC -shared -I$ERLANG_ROOT/usr/include \
    -I/usr/local/include -L/usr/local/lib \
    -o seatuya_nif.so seatuya_nif.c -lseatuya
```

Replace `$ERLANG_ROOT` with your Erlang installation path (e.g. `/usr/lib/erlang`).

## Using in a Gleam project

1. Copy `seatuya.gleam` into your project's `src/` directory.
2. Copy `seatuya_nif.erl` and `seatuya_ffi.erl` into your project's `src/` directory.
3. Copy `seatuya_nif.so` to your project root or set the `SEATUYA_LIB` env var.
4. Add the module to your `gleam.toml` build target.

## Usage

```gleam
import seatuya.{TuyaDevice, create, turn_on, turn_off, status, destroy, version}

pub fn main() {
  let assert Ok(dev) = create("device-id", "192.168.1.100", "local-key", "3.3")

  let assert Ok(resp) = turn_on(dev, 1)
  io.println(resp)

  let assert Ok(s) = status(dev)
  io.println(s)

  let assert Ok(resp) = turn_off(dev, 1)
  io.println(resp)

  destroy(dev)
}
```

### Type-aware set_value

```gleam
import seatuya.{set_value, Value}

set_value(dev, 1, BoolVal(True))        // boolean
set_value(dev, 2, IntVal(25))           // integer
set_value(dev, 3, StringVal("hello"))   // string
set_value(dev, 4, FloatVal(23.5))       // float
```

### Constants

```gleam
import seatuya.{cmd_control, cmd_dp_query, default_port}
```

All 43 Tuya command constants plus protocol version constants are exported.

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
The Gleam module maps one-to-one with the C functions. String ownership is
managed automatically: malloc'd C strings are consumed into Gleam strings
(and freed) before returning.
