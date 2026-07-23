# Factor FFI Bindings for libseatuya

Factor bindings using the ALIEN FFI library (`alien.syntax`, `alien.c-types`,
etc.) for direct C interop.  The binding loads `libseatuya.so` at runtime
via `dlopen`/`add-library`.

## Prerequisites

- Factor 0.99+
- libseatuya installed (`make install`)

## Usage

```factor
USE: seatuya

"0123456789abcdef01234567" "192.168.1.100" "0123456789abcdef" "3.4"
tuya-create [ "ERROR" print 1 exit ] unless* => [ dev ]

dev 1 tuya-turn-on consume-cstr .
dev tuya-status consume-cstr .
dev tuya-destroy
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.

The module defines wrapper words for every C function.  C `bool` values
become Factor `t`/`f` booleans.  Malloc'd C strings are returned through
`consume-cstr` (copied into a Factor string, then freed).

### Key words

| Word | Stack effect | Description |
|---|---|---|
| `tuya-create` | `( device-id address local-key ver -- void*/f )` | Create + connect |
| `tuya-destroy` | `( dev -- )` | Free resources |
| `tuya-turn-on` | `( dev switch-dp -- str/f )` | Turn on a DP |
| `tuya-turn-off` | `( dev switch-dp -- str/f )` | Turn off a DP |
| `tuya-status` | `( dev -- str/f )` | Query all DP values |
| `tuya-is-connected` | `( dev -- ? )` | Connection state |
| `consume-cstr` | `( alien -- str/f )` | Copy + free C string |

### Constants

| Symbol | Description |
|---|---|
| `commands` | `H{ "control" 7 "dp-query" 10 ... }` -- 43 commands |
| `protocols` | `H{ "v31" 0 ... }` |
| `session-states` | `H{ "invalid" 0 ... }` |
| `socket-states` | `H{ "no-such-host" 0 ... }` |
| `default-port` | 6668 |
| `bufsize` | 1024 |

### Library path

Set the `SEATUYA_LIB` environment variable to override the library path.
Defaults: `libseatuya.so` (Linux), `libseatuya.dylib` (macOS),
`seatuya.dll` (Windows).
