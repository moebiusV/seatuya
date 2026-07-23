# Rust FFI Bindings for libseatuya

Pure Rust binding using raw `extern "C"` declarations.  The opaque C
pointer is wrapped in a `Device` struct that owns the handle and drops
it automatically (RAII).

## Prerequisites

- Rust 1.70+ (edition 2021)
- libseatuya installed (`make install`)

## Build and run

```sh
cargo build
cargo run --example example
```

## Usage

```rust
use seatuya::Device;

let dev = Device::create(device_id, "192.168.1.100", local_key, "3.4")?;
println!("{:?}", dev.turn_on(1));
println!("{:?}", dev.status());
// Device is automatically destroyed when dropped
```

## API

See the [seatuya(3)](../../seatuya.3) manpage.  Methods on the `Device`
struct.  `Option<String>` for nullable returns, `Result<T, Error>` for
fallible operations.  `Drop` impl calls `tuya_destroy` automatically.
