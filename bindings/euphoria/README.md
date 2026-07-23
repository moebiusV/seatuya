# Euphoria FFI Bindings for libseatuya

Euphoria 4.1+ binding using `c_func()` and `c_proc()` for C interop.
Each C function is registered with `define_c_func`/`define_c_proc` at
load time, then called via pre-computed routine IDs.

## Prerequisites
- [Euphoria](https://openeuphoria.org/) 4.1+
- libseatuya installed

## Usage
```euphoria
atom dev = seatuya_create(did, ip, key, "3.4")
printf(1, "%s\n", {seatuya_turn_on(dev, 1)})
seatuya_destroy(dev)
```

Run: `eui example.ex`
