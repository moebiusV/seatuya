# PHP FFI Bindings for libseatuya

PHP 7.4+ binding using the built-in `FFI` class.  The entire C header
is declared via `FFI::cdef()` and wrapped in a static `Seatuya` class
with type-safe methods and `match`-based value dispatch.

## Prerequisites
- PHP 7.4+ with FFI enabled (`php -m | grep FFI`)
- libseatuya installed

## Usage
```php
$dev = Seatuya::create($deviceId, '192.168.1.100', $localKey, '3.4');
echo Seatuya::turnOn($dev, 1), "\n";
Seatuya::destroy($dev);
```

Run: `php example.php`
