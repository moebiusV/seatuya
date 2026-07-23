# Squeak Smalltalk FFI Bindings for libseatuya

Squeak binding using the built-in ExternalFunction / ExternalLibrary
framework.  Each C function is declared as a class-side method with
the `<cdecl:>` pragma specifying return type, function name, and
argument types.  The opaque `tuya_device_t*` is stored as an
`ExternalAddress` in the `SeatuyaDevice` instance variable `handle`.

## Prerequisites
- [Squeak](https://squeak.org/) 5.0+ with FFI support
- libseatuya installed (`make install`)

## Usage

In a Squeak workspace or via file-in:
```smalltalk
FileStream fileIn: 'seatuya.st'.
dev := SeatuyaDevice create: deviceId address: '192.168.1.100'
          localKey: key version: '3.4'.
Transcript show: (dev turnOn: 1); cr.
dev destroy.
```

Overrides `SEATUYA_LIB` env var.  Type-aware `setValue:forDP:` dispatches
on Smalltalk class: String → setValueString, Float → setValueFloat,
Integer → setValueInt, Boolean → setValueBool.

## Note

Squeak is a separate dialect from Pharo.  Squeak's FFI is more stable
and battle-tested.  Pharo's FFI (UFFI) is being rewritten and was
deferred until the API stabilizes.
