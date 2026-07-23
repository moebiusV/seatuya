# Tcl FFI Bindings for libseatuya

Pure Tcl binding using the Ffidl extension (`package require ffidl`).
The `seatuya` namespace provides an ensemble of commands that wrap every
C function with automatic string ownership management.

## Prerequisites

- Tcl 8.6+
- Ffidl (package `tclffi` on Debian/Ubuntu: `apt-get install tclffi`)
- libseatuya installed (`make install`)

## Usage

```tcl
package require seatuya

set dev [seatuya create $device_id $ip $local_key "3.4"]

# Type-aware setter
puts [seatuya set-value $dev 1 true]      ;# boolean
puts [seatuya set-value $dev 2 25]         ;# integer
puts [seatuya set-value $dev 3 "hello"]    ;# string
puts [seatuya set-value $dev 4 23.5]       ;# float

# Convenience wrappers
puts [seatuya turn-on $dev 1]
puts [seatuya status $dev]
puts [seatuya turn-off $dev 1]

seatuya destroy $dev
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
The `seatuya` ensemble re-exports every C function as a Tcl proc with
kebab-case naming.  Constants are available as `$seatuya::CMD_*`,
`$seatuya::PROTO_*`, etc.
