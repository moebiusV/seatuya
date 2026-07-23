# Objective-C Bindings for libseatuya

Pure Objective-C wrapper around the C ABI.  The opaque `tuya_device_t*`
is wrapped in `SeatuyaDevice` with full ARC memory management — dealloc
calls `tuya_destroy` automatically.

## Prerequisites
- macOS / GNUstep with Clang
- libseatuya installed (`make install`)

## Build
```sh
clang -framework Foundation -lseatuya example.m Seatuya.m -o example
```

## Usage
```objc
SeatuyaDevice *dev = [[SeatuyaDevice alloc] initWithDeviceId:id
                                                      address:@"192.168.1.100"
                                                     localKey:key
                                                      version:@"3.4"];
NSLog(@"%@", [dev turnOn:1]);
NSLog(@"%@", [dev status]);
// dealloc destroys the handle automatically
```
