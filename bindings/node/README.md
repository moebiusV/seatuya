# Node.js FFI Bindings for libseatuya

Pure JavaScript binding using [ffi-napi](https://github.com/node-ffi-napi/node-ffi-napi)
to call libseatuya directly — no native compilation required.

## Prerequisites

```sh
npm install ffi-napi ref-napi
```

libseatuya must be installed (`make install`) or the path set via `SEATUYA_LIB`.

## Usage

```js
const seatuya = require('./seatuya.js');

// All-in-one: create, connect, and negotiate session
const dev = seatuya.create(deviceId, '192.168.1.100', localKey, '3.4');

// Type-aware setter: dispatches to the right C function by JS type
seatuya.setValue(dev, 1, true);        // boolean → tuya_set_value_bool
seatuya.setValue(dev, 2, 25);          // integer → tuya_set_value_int
seatuya.setValue(dev, 3, 'hello');     // string  → tuya_set_value_string
seatuya.setValue(dev, 4, 23.5);        // float   → tuya_set_value_float

// Convenience wrappers
seatuya.turnOn(dev, 1);
console.log(seatuya.status(dev));
seatuya.turnOff(dev, 1);

// Teardown
seatuya.destroy(dev);
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
Every C function is available through this module with JavaScript-idiomatic
naming (camelCase instead of snake_case).  The `Command`, `Protocol`,
`SessionState`, and `SocketState` enums are exported as objects with
symbolic keys.
