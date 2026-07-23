# Dart FFI Bindings for libseatuya

Pure Dart binding using `dart:ffi`.  Requires Dart 2.17+.

## Prerequisites

- Dart SDK 2.17+
- libseatuya installed (`make install`)

## Run

```sh
dart run example.dart
```

## Usage

```dart
import 'seatuya.dart';

final dev = create(deviceId, '192.168.1.100', localKey, '3.4');
print(turnOn(dev, 1));
print(status(dev));
destroy(dev);
```

## API

See the [seatuya(3)](../../seatuya.3) manpage.  Top-level functions mirror
the C API with camelCase names.  Dart's type system distinguishes bool/int/
double/string for the `setValue` dispatcher.
