# seatuya

A C wrapper library for tuyapp, providing a stable C ABI for
controlling Tuya / Smart Life devices locally and via the cloud.
Supports protocol versions 3.1, 3.3, 3.4, and 3.5.

## Why seatuya?

The Tuya local protocol has been implemented in many languages --
tinytuya (Python), tuyapi (Node.js), tuyapp (C++), and others (see
"Related projects" below).  Each one works well in its own ecosystem.
seatuya takes a different approach: wrap the protocol behind a plain
C ABI so that any language with a foreign-function interface can use
it.  Opaque handles, C strings, ints, enums -- no templates, no
exceptions, no mangled symbols.  If your language can call `dlopen`,
it can control Tuya devices.

The newLISP modules shipped in this repository are a proof of concept.
newLISP has no Tuya support of its own and never will.  But with
seatuya installed, a thin FFI wrapper (seatuya.lsp) gives it the
full local-control API, and a 530-line script (seatuya-wizard.lsp)
replicates the entire tinytuya wizard -- cloud authentication, device
enumeration, UDP scanning, config generation -- in a language the Tuya
developers have never heard of.  That is the point: write the C
library once, and every language gets Tuya for free.

## Why use seatuya?

seatuya is built on tuyapp and modeled after tinytuya.  It fills a
different niche: a C ABI that any language can call.

1. **No runtime dependencies.**  seatuya-wizard is a statically-linked
   binary.  Copy it to a machine and run it.  No interpreter, no
   package manager, no dependency resolution.  It works on a bare
   Debian container, a FreeBSD jail, or a Raspberry Pi with nothing
   installed.

2. **Any language gets Tuya for free.**  tuyapp is C++ and tinytuya
   is Python -- both are great in their ecosystems, but not every
   project uses those languages.  seatuya exposes opaque handles,
   C strings, and ints across the ABI boundary.  If your language can
   call `dlopen`, it can control Tuya devices.  The newLISP modules
   prove this: under 300 lines of FFI wrapping, and a language with zero
   IoT ecosystem gets full local control and a cloud wizard.  The
   same works for Lua, Tcl, Forth, Zig, Nim, Janet, Racket --
   whatever you prefer.

3. **FFI-clean header with no preprocessor constants.**  Most C
   libraries define command codes, protocol versions, and buffer sizes
   as `#define` macros.  Macros disappear after preprocessing -- they
   exist only in the C compiler's world.  An FFI caller in Lua or
   newLISP never sees them, so the integrator has to read the header,
   copy every numeric value by hand, and keep the copies in sync when
   the library updates.  seatuya uses `enum` and `const` for every
   public constant.  Enums are real symbols: they show up in debug
   info, they have addresses, and FFI tools can extract them
   automatically.  Nothing in `seatuya.h` requires a C preprocessor
   to use.

4. **Portable across every major platform.**  Builds with standard
   autotools on Linux (any distribution), macOS, FreeBSD, OpenBSD,
   NetBSD, and Windows.  Starter packaging for 10 distributions is
   included under `dist/`.

5. **Self-contained wizard that uses your system's SSL.**  Tuya
   devices use local encryption keys that are not stored on the
   device itself -- you have to fetch them from the Tuya Cloud API
   once, using your developer account credentials.  tinytuya's
   wizard does this, and so does seatuya-wizard: authenticate, pull
   your device list with local keys, then UDP-scan your network to
   match devices to IP addresses.  seatuya-wizard links directly
   against the system's libcrypto and libtls (or libssl) -- the same
   libraries that sshd, curl, and your package manager already depend
   on.  The output is the same `devices.json` and `tinytuya.json`
   that tinytuya produces, so existing workflows that consume those
   files keep working.

6. **Predictable, auditable behavior.**  A C library with a manpage, a
   clean header, and no magic.  The entire public API fits in one
   header file.  You can read it, understand it, and trust it on a
   system where reliability matters -- a production IoT gateway, a
   brewery controller, an HVAC system.

7. **Familiar API -- if you know tinytuya, you know seatuya.**  The
   function names, argument order, and semantics deliberately mirror
   tinytuya's `Device` class: `tuya_create`, `tuya_turn_on`,
   `tuya_status`, `tuya_set_value_int`, `tuya_reconnect`,
   etc.  Anyone who has used tinytuya can read seatuya code (C or
   newLISP) and understand it immediately, and vice versa.  The API
   mapping table in the "Device classes" section below shows the
   correspondence line by line.  This means porting tinytuya scripts
   to C or newLISP is mechanical translation, not a learning curve.

## What is included

**Library (C ABI):**

| File | Description |
|------|-------------|
| `libseatuya.so` / `libseatuya.a` | shared and static library |
| `seatuya/seatuya.h` | public header (pure C17) |
| `seatuya.3` | section 3 manpage |

**newLISP modules:**

| File | Description |
|------|-------------|
| `find-lib.lsp` | cross-platform shared-library discovery |
| `crypto.lsp` | complete libcrypto FFI wrapper (native calls, caller-owned buffers, SHA3, HMAC, PBKDF2, CSPRNG) |
| `libtls.lsp` | libtls FFI wrapper for HTTPS |
| `seatuya.lsp` | newLISP bindings for libseatuya |
| `tuya-devices.lsp` | device classes (OutletDevice, BulbDevice, CoverDevice, ThermostatDevice, SocketDevice, ClimateDevice, DoorbellDevice, IRRemoteControlDevice, InverterHeatPumpDevice, PresenceDetectorDevice) |

**Example programs (C):**

| File | Description |
|------|-------------|
| `sousvide-ramp` | temperature ramp controller for Inkbird sous vide devices |
| `seatuya-wizard` | cloud wizard (libtls backend) |
| `seatuya-wizard-openssl` | cloud wizard (OpenSSL backend) |

**Example programs (newLISP):**

| File | Description |
|------|-------------|
| `sousvide-ramp.lsp` | same ramp controller, pure newLISP via FFI |
| `seatuya-wizard.lsp` | full tinytuya wizard clone in newLISP |

**Distribution packaging:**

Starter packaging for RPM, Debian, Arch, Alpine, Gentoo, Slackware,
FreeBSD, OpenBSD, NetBSD, and NixOS under `dist/`.
See `README.distributions` for details.

## Building

```sh
./fetch-deps.sh        # fetches tuyapp (and jsoncpp if not installed)
autoreconf -fi
./configure
make
make check
make install
```

Dependencies are fetched on demand by `fetch-deps.sh` -- nothing
third-party is shipped in the repository.  System-installed libraries
are preferred when available.

If libtls is available, the libtls-based wizard is also built.
`configure` will detect it automatically and print a hint with the
install command for your distribution if it is missing.

## Dependencies

**Required:**

| Dependency | Notes |
|------------|-------|
| OpenSSL or LibreSSL | system crypto library |
| C17 compiler | gcc 8+, clang 6+, MSVC 2019+ |
| C++14 compiler | for building tuyapp internals |
| GNU autotools | autoconf, automake, libtool (only when building from a git checkout; release tarballs ship a pre-generated configure) |

**Fetched automatically:**

| Dependency | Notes |
|------------|-------|
| tuyapp | C++ Tuya protocol library |
| jsoncpp | JSON parser (system copy preferred) |

**Optional:**

| Dependency | Notes |
|------------|-------|
| libtls | for the libtls wizard variant |
| newLISP 10.7+ | for the newLISP examples and modules |

## Using from other languages

The whole point of seatuya is that you do not need to use C.  After
`make install`, any language with FFI can load `libseatuya.so` and call
its functions.  The API uses only C types: pointers to opaque structs,
char pointers, ints, and enums.  No C++ types cross the ABI boundary.

The newLISP device classes (`tuya-devices.lsp`) show what this looks
like in practice.  Controlling a device reads like this:

```newlisp
(load "tuya-devices.lsp")

(new TuyaDevice 'd)
(d "3.4" "192.168.1.100" device-id local-key)

; turn on switch (data point 1)
(println (d:turn-on 1))

; query all data points
(println (d:status))

(d:destroy)
(delete 'd)
```

No buffer management, no byte counting, no pointer arithmetic.
The high-level methods (`turn-on`, `turn-off`, `set-value`,
`status`, `heartbeat`) each perform a complete round-trip internally
and return the decoded JSON response.

For comparison, the same thing in C:

```c
#include <seatuya/seatuya.h>
#include <stdio.h>

tuya_device_t *d = tuya_create(device_id, "192.168.1.100", local_key, "3.4");

/* turn on switch (data point 1) */
char *resp = tuya_turn_on(d, 1);
printf("%s\n", resp);
tuya_free_string(resp);

/* query all data points */
resp = tuya_status(d);
printf("%s\n", resp);
tuya_free_string(resp);

tuya_destroy(d);
```

The same approach works in Python ctypes, Lua FFI, Ruby FFI, Tcl,
Zig, Nim, Racket, Janet, or anything else that can call C functions.
`seatuya.lsp` is under 250 lines.  A wrapper in your language of choice
would be about the same.

### Data points and the interaction cycle

Every Tuya device exposes its state through numbered **data points**
(DPs).  A DP is just an integer key with a typed value -- boolean,
integer, string, or enum.  DP 1 on a smart plug is typically the
power switch (true/false).  DP 2 on a cover motor might be the
position (0-100).  DP 103 on an Inkbird sous vide is the target
temperature (integer, Celsius times 10).  The numbers are
device-specific, assigned by the manufacturer, and discoverable
through the Tuya cloud API or by querying the device directly.

The Tuya local protocol treats every interaction the same way,
regardless of device type.  To change a DP value or query the
device's current state, the caller performs a five-step round-trip:

1. **Generate payload** -- build the JSON structure the device
   expects for the command type (`CONTROL` to set a value,
   `DP_QUERY` to read state), embedding the device ID and the
   DP key-value pair.
2. **Build message** -- encrypt and frame the payload into a Tuya
   protocol packet using the device's local key.
3. **Send** -- write the packet to the TCP socket.
4. **Receive** -- read the device's response packet.
5. **Decode** -- decrypt and extract the JSON response.

Using the low-level API, that cycle looks like this in C:

```c
/* set DP 1 to true (turn on a smart plug) */
char *payload = tuya_generate_payload(d, TUYA_CMD_CONTROL, device_id, "{\"1\":true}");
unsigned char buf[1024];
int n = tuya_build_message(d, buf, TUYA_CMD_CONTROL, payload, local_key);
tuya_free_string(payload);
tuya_send(d, buf, n);
n = tuya_receive(d, buf, sizeof buf, 0);
char *response = tuya_decode_message(d, buf, n, local_key);
/* ... use response (the device's JSON reply) ... */
tuya_free_string(response);
```

That is a lot of boilerplate for "turn on the plug".  Every
interaction follows exactly the same pattern -- the only things that
change are the command type, the DP number, and the value.  So the
library wraps the entire cycle into single-call functions:

```c
/* same thing, high-level API */
char *response = tuya_turn_on(d, 1);
/* ... use response ... */
tuya_free_string(response);
```

The high-level functions (`tuya_set_value_bool`, `tuya_set_value_int`,
`tuya_set_value_string`, `tuya_set_value_float`, `tuya_turn_on`,
`tuya_turn_off`, `tuya_status`, `tuya_heartbeat`) all perform the
full five-step round-trip internally, using the credentials and
internal buffer stored on the device handle.  They return a `malloc`'d
JSON response string (freed with `tuya_free_string`), or NULL on error.

The low-level API remains available for cases where you need
fine-grained control -- pipelining multiple commands, custom command
types, or async workflows where you manage the send/receive timing
yourself.

### From data points to named methods

The high-level C functions still require the caller to know the raw
DP numbers.  That is fine for a C program that controls one specific
device, but for a general-purpose library it helps to have one more
layer: named methods that map human-readable operations to the right
DP for each device category.

In newLISP, the device classes provide this.  Each class knows
its own DP layout and exposes named methods:

```newlisp
; Raw DP -- you need to know that DP 1 is the power switch, DP 22 is brightness, DP 24 is colour:
(d:set-value 1 true)
(d:set-value 22 500)
(d:set-value 24 "00dc004603e8")

; Named methods -- the class knows the DP numbers:
(my-bulb:turn-on)
(my-bulb:set-brightness 500)
(my-bulb:set-colour 255 0 0)    ; RGB, converted to HSV hex internally
```

The progression is: raw protocol (5 steps) -> high-level function
(1 step, DP number) -> named device method (1 step, no DP number).
Each layer hides exactly one kind of detail: the C library hides
buffer management and encryption, the `TuyaDevice` methods hide the
round-trip ceremony, and the device subclasses hide device-specific
DP mappings.

## Device classes (newLISP)

`tuya-devices.lsp` provides high-level device classes using newLISP's
context-based OOP (`new`/`delete`).  Each class maps convenience methods
to the correct data point (DP) numbers for a device category, so you
write `my-plug:turn-on` instead of raw `set-value` calls.

### Relationship to tinytuya

tinytuya (Python) has three built-in device classes -- `OutletDevice`,
`BulbDevice`, and `CoverDevice` -- plus a base `Device` class with
`set_value()`, `set_status()`, and `status()`.  Additional device types
(`ThermostatDevice`, `IRRemoteControlDevice`, `DoorbellDevice`,
`ClimateDevice`, and others) live in tinytuya's community-contributed
`Contrib` module.

seatuya mirrors this in `tuya-devices.lsp`:

- **`TuyaDevice`** is the base class, equivalent to tinytuya's `Device`.
  `d:set-value`, `d:status`, `d:turn-on` are the equivalents of
  `d.set_value()`, `d.status()`, `d.turn_on()`.

- **`OutletDevice`**, **`BulbDevice`**, **`CoverDevice`**, etc. are
  subclasses (via `new`) that add named methods with hardcoded DP
  numbers.  `OutletDevice`, `BulbDevice`, and `CoverDevice` follow the
  same DP mappings as tinytuya's core classes.  The remaining classes
  follow their counterparts in tinytuya's community-contributed
  `Contrib` module.

Read-only devices like humidity sensors or air quality monitors work
through `my-dev:status` on any device class but lack named getters.
There is no generic `SensorDevice` yet.

### API mapping

The API mirrors tinytuya's `Device` class closely enough that the
mapping is mechanical.  If you know tinytuya, you already know
seatuya -- just change the syntax.

**Base TuyaDevice (lifecycle and connection):**

| tinytuya (Python) | seatuya (C) | seatuya (newLISP) |
|--------------------|-------------|---------------------|
| `d = Device(id, addr, key, ver)` | `tuya_device_t *d = tuya_create(id, addr, key, ver)` | `(new TuyaDevice 'd) (d ver addr id key)` |
| *(incremental setup)* | `tuya_alloc(ver)` | *(use tuya:alloc directly)* |
| *(incremental setup)* | `tuya_set_credentials(d, id, key)` | *(use tuya:set-credentials directly)* |
| *(incremental setup)* | `tuya_connect(d, addr)` | *(use tuya:connect directly)* |
| *(incremental setup)* | `tuya_negotiate_session(d, key)` | *(use tuya:negotiate-session directly)* |
| `d.close()` | `tuya_disconnect(d)` | `(d:destroy)` |
| `del d` | `tuya_destroy(d)` | `(d:destroy) (delete 'd)` |

**High-level operations (full round-trip):**

| tinytuya (Python) | seatuya (C) | seatuya (newLISP) |
|--------------------|-------------|---------------------|
| `d.turn_on(switch)` | `tuya_turn_on(d, dp)` | `(d:turn-on dp)` |
| `d.turn_off(switch)` | `tuya_turn_off(d, dp)` | `(d:turn-off dp)` |
| `d.set_value(dp, value)` | `tuya_set_value_bool(d, dp, val)` | `(d:set-value dp val)` |
| | `tuya_set_value_int(d, dp, val)` | *(type auto-detected)* |
| | `tuya_set_value_string(d, dp, val)` | |
| | `tuya_set_value_float(d, dp, val)` | |
| `d.status()` | `tuya_status(d)` | `(d:status)` |
| `d.heartbeat()` | `tuya_heartbeat(d)` | `(d:heartbeat)` |
| *(reconnect logic in set_status)* | `tuya_reconnect(d)` | `(d:reconnect)` |

**Credential and state getters:**

| tinytuya (Python) | seatuya (C) | seatuya (newLISP) |
|--------------------|-------------|---------------------|
| `d.id` | `tuya_get_device_id(d)` | `d:id` |
| `d.local_key` | `tuya_get_local_key(d)` | `d:local-key` |
| `d.address` | `tuya_get_ip(d)` | `d:address` |
| `d.version` | *(n/a)* | `d:version` |
| *(n/a)* | `tuya_get_protocol(d)` | `(tuya:get-protocol d:handle)` |
| *(n/a)* | `tuya_get_session_state(d)` | `(tuya:get-session-state d:handle)` |
| *(n/a)* | `tuya_get_socket_state(d)` | `(tuya:get-socket-state d:handle)` |
| *(n/a)* | `tuya_get_last_error(d)` | `(tuya:get-last-error d:handle)` |

**Low-level (no tinytuya equivalent -- for pipelining or custom commands):**

| seatuya (C) | seatuya (newLISP) |
|-------------|---------------------|
| `tuya_generate_payload(d, cmd, id, dps)` | `(tuya:generate-payload d:handle cmd id dps)` |
| `tuya_build_message(d, buf, cmd, payload, key)` | `(tuya:build-message d:handle cmd payload key)` |
| `tuya_send(d, buf, size)` | `(tuya:send d:handle buf)` |
| `tuya_receive(d, buf, max, min)` | `(tuya:receive d:handle)` |
| `tuya_decode_message(d, buf, size, key)` | `(tuya:decode-message d:handle buf key)` |
| `tuya_free_string(str)` | *(automatic)* |

tinytuya's `set_value` accepts any Python type and serializes it.
The C API splits this into four typed functions because C has no
dynamic typing.  The newLISP `TuyaDevice:set-value` (and `tuya:set-value`
underneath) inspects the value and dispatches to the right C function.

All `char *` returns from C are `malloc`'d.  C callers free them with
`tuya_free_string()`.  The newLISP wrapper copies the string and frees
the original automatically.

### Architectural difference

tinytuya bundles connection management, credentials, message framing,
and device semantics into a single `Device` object.  seatuya splits
these across two layers:

1. **`libseatuya` (C)** -- transport, encryption, framing, credential
   storage, and high-level round-trip operations (`tuya_set_value_*`,
   `tuya_status`, `tuya_turn_on`, etc.).
2. **`tuya-devices.lsp` (newLISP)** -- `TuyaDevice` base class (mirrors
   tinytuya's `Device` with `d:turn-on`, `d:status`, etc.) plus device
   subclasses with DP mappings and named methods.

`seatuya.lsp` is a thin FFI wrapper that imports the C functions into
newLISP.  `TuyaDevice` wraps those into `obj:method` form so the API
reads identically across Python, C, and newLISP.

Each device instance is a newLISP context cloned via `new`.  You can
always reach through to the raw handle with `d:handle` and call
`tuya:` functions directly -- the abstraction is a convenience, not a
cage.

### Supported device types

| Class | tinytuya equivalent | Key methods |
|-------|---------------------|-------------|
| `OutletDevice` | `OutletDevice` (core) | `turn-on`, `turn-off`, `set-dimmer` |
| `BulbDevice` | `BulbDevice` (core) | `set-colour`, `set-brightness-pct`, `set-colourtemp-pct`, `set-white` |
| `CoverDevice` | `CoverDevice` (core) | `open-cover`, `close-cover`, `stop-cover`, `set-position` |
| `ThermostatDevice` | `ThermostatDevice` (contrib) | `set-temperature`, `set-mode`, `get-temperature` |
| `SocketDevice` | `SocketDevice` (contrib) | `turn-on`, `turn-off`, `get-energy` |
| `ClimateDevice` | `ClimateDevice` (contrib) | `set-temperature`, `set-mode`, `set-fan-speed` |
| `DoorbellDevice` | `DoorbellDevice` (contrib) | `set-volume`, `set-motion-switch`, `set-motion-sensitivity` |
| `IRRemoteControlDevice` | `IRRemoteControlDevice` (contrib) | `study-start`, `study-end`, `send-button`, `send-key` |
| `InverterHeatPumpDevice` | `InverterHeatPumpDevice` (contrib) | `set-target-temp`, `set-silence-mode`, `get-inlet-temp` |
| `PresenceDetectorDevice` | `PresenceDetectorDevice` (contrib) | `set-sensitivity`, `set-near-detection`, `set-far-detection` |

All classes also support `status` (query all DPs), `reconnect`
(re-establish a dropped connection, including session negotiation
for protocol 3.4+), and `destroy` (disconnect and free the handle).

### Example: smart plug

```newlisp
(load "tuya-devices.lsp")

(new OutletDevice 'my-plug)
(my-plug "3.3" "192.168.1.50" "device-id" "local-key")
(my-plug:turn-on)
(my-plug:status)
(my-plug:turn-off)
(my-plug:destroy)
(delete 'my-plug)
```

### Example: RGB bulb

```newlisp
(new BulbDevice 'my-bulb)
(my-bulb "3.4" "192.168.1.51" "device-id" "local-key")
(my-bulb:turn-on)
(my-bulb:set-colour 255 0 0)    ; red
(my-bulb:set-brightness-pct 50) ; half brightness
(my-bulb:set-white 500 500)     ; white mode, mid brightness + temp
(my-bulb:destroy)
(delete 'my-bulb)
```

### Example: thermostat with custom DP map

```newlisp
;; Default DPs: 1=switch, 2=target, 3=current, 4=mode, scale=10
;; Override for a device that uses different DP numbers:
(new ThermostatDevice 'my-therm)
(my-therm "3.3" "192.168.1.52" "dev-id" "key"
           2 16 24 4 1)         ; switch=2, target=16, current=24, mode=4, scale=1
(my-therm:set-temperature 72)
(my-therm:get-temperature)      ; reads current temp from device
(my-therm:destroy)
(delete 'my-therm)
```

### Example: Inkbird sous vide (custom DP map)

The `sousvide-ramp.lsp` example uses `ThermostatDevice` with Inkbird's
non-standard DP numbers (101-110 instead of the usual 1-4):

```newlisp
(new ThermostatDevice 'sv)
(sv version ip device-id local-key
    101 103 104 102 10)           ; power=101, target=103, current=104, status=102, scale=10
(power-on)                        ; wrapper around (sv:turn-on)
(set-temperature-f 145.0)         ; wrapper: F->C conversion, then (sv:set-temperature celsius)
(query-status)                    ; wrapper around (sv:status)
(sv:destroy)
(delete 'sv)
```

The named wrappers (`power-on`, `set-temperature-f`, `query-status`)
are application-level functions that call the device methods, which call
`tuya:set-value`, which calls the raw FFI.  Each layer hides the right
details: the device class hides DP numbers, the convenience functions
hide temperature conversion, the FFI wrapper hides buffers.

### DP number customization

Every constructor accepts optional DP number overrides for devices that
use non-standard mappings.  The defaults match the most common Tuya
device configurations, as documented by tinytuya.

## Related projects

The Tuya local protocol has been reverse-engineered and implemented
by many projects across different languages.  seatuya builds directly
on tuyapp and takes its API design from tinytuya, but the broader
ecosystem deserves credit -- the collective work of these projects is
what makes local Tuya control possible at all.

| Project | Language | Notes |
|---------|----------|-------|
| [tinytuya](https://github.com/jasonacox/tinytuya) | Python | Widely used local-control library. seatuya's API, device classes, DP mappings, and device subclass hierarchy are modeled directly on tinytuya. |
| [tuyapp](https://github.com/rnascunha/tuyapp) | C++ | Protocol implementation that seatuya wraps. Provides the encryption, framing, and session negotiation that libseatuya exposes through a C ABI. |
| [tuya-local](https://github.com/make-all/tuya-local) | Python | Home Assistant custom integration for local control. |
| [tuyapi](https://github.com/codetheweb/tuyapi) | Node.js | One of the earliest local-control implementations. |
| [TuyaOpen](https://github.com/tuya/TuyaOpen) | C | Tuya's official open-source SDK for embedded development. |
| [tuyaha](https://github.com/PaulAnnewordup/tuyaha) | Python | Cloud-only Tuya API wrapper. |
| [localtuya](https://github.com/rospogrigio/localtuya) | Python | Another Home Assistant integration for local control. |
| [tuya-mqtt](https://github.com/TheAgentK/tuya-mqtt) | Node.js | MQTT bridge for Tuya devices. |
| [TuyaOS](https://developer.tuya.com/en/tuyaos) | C | Tuya's commercial embedded OS (closed source, listed for context). |

seatuya's contribution is not a new protocol implementation -- tuyapp
already did that.  It is a C ABI layer that makes the protocol
accessible from any language with FFI, plus a device-class hierarchy
(inspired by tinytuya) that maps named operations to raw DP numbers.

## License

BSD-2-Clause.  See `COPYING` for details.

tuyapp is licensed under GPL-3.0+ (see `deps/tuyapp/LICENSE` after fetch).
jsoncpp is licensed under MIT (see `deps/jsoncpp/LICENSE` after fetch).
