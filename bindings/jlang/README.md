# J FFI Bindings for libseatuya

J bindings using the `dll` addon's `cd` conjunction for direct C interop.
The binding loads `libseatuya.so` at runtime via `cdbind`.

## Prerequisites

- J9.4+ with the `dll` addon (included in standard library)
- libseatuya installed (`make install`)

## Usage

```j
load 'seatuya'

dev=: tuya_create device_id;ip;local_key;ver
if. dev = 0 do. 2!:55 (1) end.

smoutput tuya_turn_on dev;1
smoutput tuya_status dev

tuya_destroy dev
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.

### Calling conventions

Each C function is wrapped in a J verb.  Arguments are passed as boxed lists:

| Verb | Arguments | Returns |
|---|---|---|
| `tuya_create` | `device_id;address;local_key;ver` | device pointer (integer) |
| `tuya_destroy` | `dev` | (void) |
| `tuya_turn_on` | `dev;switch_dp` | JSON response string |
| `tuya_turn_off` | `dev;switch_dp` | JSON response string |
| `tuya_status` | `dev` | JSON response string |
| `tuya_heartbeat` | `dev` | JSON response string |
| `tuya_set_value` | `dev;dp;value` | JSON response string |
| `tuya_is_connected` | `dev` | J boolean (0/1) |
| `tuya_version` | (none) | version string |
| `tuya_get_device_id` | `dev` | device ID string |
| `tuya_get_local_key` | `dev` | local key string |
| `tuya_get_ip` | `dev` | IP string |

### Constants

| Symbol | Description |
|---|---|
| `CMD_CONTROL` etc. | 43 command constant nouns |
| `PROTO_V31`..`PROTO_V35` | Protocol version nouns |
| `SESSION_INVALID`..`SESSION_ESTABLISHED` | Session state nouns |
| `SOCK_NO_SUCH_HOST`..`SOCK_RECEIVING` | Socket state nouns |
| `DEFAULT_PORT` | 6668 |
| `BUFSIZE` | 1024 |

### Library path

Set the `SEATUYA_LIB` environment variable to override the library path.
Defaults to `libseatuya.so`.

### Notes

- Malloc'd C strings are automatically consumed (copied to J string, freed).
- Non-freeable C strings (internal pointers) are read via `memr` without freeing.
- Low-level buffer functions (`tuya_build_message`, `tuya_receive`, `tuya_send`)
  use J string buffers; embedded nulls in binary payloads may truncate
  (known J FFI limitation).
