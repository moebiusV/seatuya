# Python ctypes Bindings for libseatuya

Pure Python binding using the standard library `ctypes` module.
No external dependencies — works with any Python 3.6+.

## Prerequisites

- Python 3.6+
- libseatuya installed (`make install`)

## Usage

```python
import seatuya

dev = seatuya.create(device_id, "192.168.1.100", local_key, "3.4")

# Type-aware setter
print(seatuya.set_value(dev, 1, True))     # bool
print(seatuya.set_value(dev, 2, 25))       # int
print(seatuya.set_value(dev, 3, "hello"))  # str
print(seatuya.set_value(dev, 4, 23.5))     # float

print(seatuya.turn_on(dev, 1))
print(seatuya.status(dev))
print(seatuya.turn_off(dev, 1))

seatuya.destroy(dev)
```

## API

See the [seatuya(3)](../../seatuya.3) manpage. IntEnum classes provide
`Command`, `Protocol`, `SessionState`, and `SocketState`.  All returned
strings are Python strings (CTypes auto-decodes and frees malloc'd C strings).
