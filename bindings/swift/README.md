# Swift Bindings for libseatuya

Pure Swift binding using `dlopen`/`dlsym` for dynamic C interop.
Uses `OpaquePointer` for the device handle and `@convention(c)` for
type-safe function pointers.

## Prerequisites
- Swift 5.0+
- libseatuya installed

## Usage
```swift
let dev = Seatuya.create(id, "192.168.1.100", key, "3.4")!
print(Seatuya.turnOn(dev) ?? "failed")
Seatuya.destroy(dev)
```

Run: `swift example.swift`
