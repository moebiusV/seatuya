# Ruby FFI Bindings for libseatuya

Pure Ruby binding using the [ffi gem](https://github.com/ffi/ffi).
Every C function is attached with proper type signatures.

## Prerequisites

```sh
gem install ffi
```

libseatuya must be installed (`make install`).

## Usage

```ruby
require 'seatuya'

dev = Seatuya.create(device_id, "192.168.1.100", local_key, "3.4")
puts Seatuya.turn_on(dev, 1)
puts Seatuya.status(dev)
Seatuya.destroy(dev)
```

## API

See the [seatuya(3)](../../seatuya.3) manpage. All functions are module
methods on `Seatuya`.  Ruby `true`/`false` map to C `bool`.  FFI handles
memory for string returns automatically.
