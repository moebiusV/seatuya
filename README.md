# seatuya

A C wrapper library for tuyapp, providing a stable C ABI for
controlling Tuya / Smart Life devices locally and via the cloud.
Supports protocol versions 3.1, 3.3, 3.4, and 3.5.

## Why seatuya?

The Tuya ecosystem already has two solid libraries: tuyapp (C++) and
tinytuya (Python).  Both work well, but both lock you into a single
language.  If you want to talk to a Tuya device from Lua, Tcl,
newLISP, Forth, Zig, Nim, or anything else that can call a C
function, you are out of luck.

seatuya fixes that.  It wraps tuyapp's C++ internals behind a plain C
API with a stable ABI: opaque handles, no templates, no exceptions, no
mangled symbols.  Any language with a foreign-function interface (FFI)
can link to libseatuya and control Tuya devices directly, without
shelling out to Python or embedding a C++ runtime.

The newLISP modules shipped in this repository are a proof of concept.
newLISP has no Tuya support of its own and never will.  But with
seatuya installed, a thin FFI wrapper (seatuya.lsp) gives it the
full local-control API, and a 530-line script (seatuya-wizard.lsp)
replicates the entire tinytuya wizard -- cloud authentication, device
enumeration, UDP scanning, config generation -- in a language the Tuya
developers have never heard of.  That is the point: write the C
library once, and every language gets Tuya for free.

## Advantages over tinytuya and tuyapp

1. **No runtime dependencies.**  seatuya-wizard is a statically-linked
   binary.  Copy it to a machine and run it.  No Python, no pip, no
   venv, no `requirements.txt`, no resolving version conflicts between
   cryptography, pyOpenSSL, requests, and urllib3.  It works on a bare
   Debian container, a FreeBSD jail, or a Raspberry Pi with nothing
   installed.  tinytuya pulls in 15+ transitive Python packages and
   breaks when any of them ships an incompatible update.

2. **Any language gets Tuya for free.**  tuyapp locks you into C++,
   tinytuya locks you into Python.  seatuya exposes opaque handles,
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
   included under `dist/`.  tinytuya only works where Python works
   well, which excludes embedded systems, minimal containers, and
   BSDs where Python packaging is a constant headache.

5. **Self-contained wizard that uses your system's SSL.**  Tuya
   devices use local encryption keys that are not stored on the
   device itself -- you have to fetch them from the Tuya Cloud API
   once, using your developer account credentials.  tinytuya's
   wizard does this, and so does seatuya-wizard: authenticate, pull
   your device list with local keys, then UDP-scan your network to
   match devices to IP addresses.  The difference is what they need
   installed.  tinytuya depends on the Python `cryptography` package,
   which is a Rust+C hybrid that wraps the same system OpenSSL you
   already have, adding a build-time Rust compiler requirement and a
   separate update cycle managed through pip.  seatuya-wizard links
   directly against the system's libcrypto and libtls (or libssl) --
   the same libraries that sshd, curl, and your package manager
   already depend on.  There is nothing to download, no pip, no
   wheel compatibility matrix, no Rust toolchain.  If your system
   can boot and install packages, it already has everything
   seatuya-wizard needs.  The output is the same `devices.json` and
   `tinytuya.json` that tinytuya produces, so existing workflows
   that consume those files keep working.

6. **Predictable, auditable behavior.**  A C library with a manpage, a
   clean header, and no magic.  No monkey-patching, no dynamic
   dispatch, no import-time side effects.  The entire public API
   fits in one header file.  You can read it, understand it, and
   trust it on a system where reliability matters -- a production
   IoT gateway, a brewery controller, an HVAC system.  When
   tinytuya updates and changes its internal retry logic or cloud
   API parsing, you get the new behavior whether you wanted it or
   not.  seatuya's ABI does not change out from under you.

7. **Familiar API -- if you know tinytuya, you know seatuya.**  The
   function names, argument order, and semantics deliberately mirror
   tinytuya's `Device` class: `tuya_create`, `tuya_set_credentials`,
   `tuya_connect`, `tuya_turn_on`, `tuya_status`, `tuya_set_value_int`,
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
| `crypto-fast.lsp` | complete libcrypto FFI wrapper (replaces the built-in crypto.lsp with native calls, caller-owned buffers, SHA3, HMAC, PBKDF2, CSPRNG) |
| `libtls.lsp` | libtls FFI wrapper for HTTPS |
| `seatuya.lsp` | newLISP bindings for libseatuya |
| `tuya-devices.lsp` | FOOP device classes (OutletDevice, BulbDevice, CoverDevice, ThermostatDevice, SocketDevice, ClimateDevice, DoorbellDevice, IRRemoteControlDevice, InverterHeatPumpDevice, PresenceDetectorDevice) |

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

The newLISP wrapper (`seatuya.lsp`) shows what a thin FFI module looks
like in practice.  Once loaded, controlling a device reads like this:

```newlisp
(load "seatuya.lsp")

(setq dev (tuya:create "3.4"))
(tuya:set-credentials dev device-id local-key)
(tuya:connect dev "192.168.1.100")
(tuya:negotiate-session dev local-key)

; turn on switch (data point 1)
(println (tuya:turn-on dev 1))

; query all data points
(println (tuya:status dev))

(tuya:destroy dev)
```

No buffer management, no byte counting, no pointer arithmetic.
The high-level functions (`turn-on`, `turn-off`, `set-value`,
`status`, `heartbeat`) each perform a complete round-trip internally
and return the decoded JSON response.

For comparison, the same thing in C:

```c
#include <seatuya/seatuya.h>
#include <stdio.h>

tuya_device_t *dev = tuya_create("3.4");
tuya_set_credentials(dev, device_id, local_key);
tuya_connect(dev, "192.168.1.100");
tuya_negotiate_session(dev, local_key);

/* turn on switch (data point 1) */
char *resp = tuya_turn_on(dev, 1);
printf("%s\n", resp);
tuya_free_string(resp);

/* query all data points */
resp = tuya_status(dev);
printf("%s\n", resp);
tuya_free_string(resp);

tuya_destroy(dev);
```

The high-level C functions handle the entire round-trip internally.
The low-level API (`generate_payload`, `build_message`, `send`,
`receive`, `decode_message`) is still available for advanced use
cases like pipelining or custom command types.

The same approach works in Python ctypes, Lua FFI, Ruby FFI, Tcl,
Zig, Nim, Racket, Janet, or anything else that can call C functions.
`seatuya.lsp` is under 250 lines.  A wrapper in your language of choice
would be about the same.

### Convenience functions

The five-step round-trip (generate payload, build message, send,
receive, decode) is handled by the C library itself.  Store
credentials once with `tuya:set-credentials`, then use
`tuya:set-value`, `tuya:turn-on`, `tuya:turn-off`, `tuya:status`,
and `tuya:heartbeat`:

```newlisp
(tuya:set-credentials dev device-id local-key)

(tuya:turn-on dev 1)              ; turn on DP 1
(tuya:set-value dev 3 "colour")   ; set DP 3 to a string
(tuya:set-value dev 103 720)      ; set DP 103 to integer 720
(tuya:status dev)                  ; query all DPs
(tuya:reconnect dev)               ; re-establish dropped connection
```

Values are automatically formatted as the correct JSON type (boolean,
string, integer, or float) based on the newLISP value passed.  These
functions are the building blocks for the FOOP device classes below.

## Device classes (newLISP FOOP)

`tuya-devices.lsp` provides high-level device classes using newLISP's FOOP
(Functional Object-Oriented Programming) system.  Each class maps
convenience methods to the correct data point (DP) numbers for a device
category, so you write `(:turn-on plug)` instead of raw `set-value` calls.

### Relationship to tinytuya

tinytuya (Python) has three built-in device classes -- `OutletDevice`,
`BulbDevice`, and `CoverDevice` -- plus a base `Device` class with
`set_value()`, `set_status()`, and `status()`.  Additional device types
(`ThermostatDevice`, `IRRemoteControlDevice`, `DoorbellDevice`,
`ClimateDevice`, and others) live in tinytuya's community-contributed
`Contrib` module.

seatuya mirrors this in two layers:

- **`seatuya.lsp`** corresponds to tinytuya's base `Device` class.
  `tuya:set-value` and `tuya:status` are the equivalents of
  `device.set_value()` and `device.status()`.

- **`tuya-devices.lsp`** corresponds to tinytuya's device subclasses.
  `OutletDevice`, `BulbDevice`, and `CoverDevice` follow the same DP
  mappings as tinytuya's core classes.  The remaining classes follow
  their counterparts in tinytuya's community-contributed `Contrib` module.

Read-only devices like humidity sensors or air quality monitors work
through `:status` on any device class but lack named getters.  There is
no generic `SensorDevice` yet.

### API mapping

The API mirrors tinytuya's `Device` class closely enough that the
mapping is mechanical.  If you know tinytuya, you already know
seatuya -- just change the syntax.

**Base Device (lifecycle and connection):**

| tinytuya (Python) | seatuya (C) | seatuya (newLISP) |
|--------------------|-------------|---------------------|
| `Device(id, addr, key, ver)` | `tuya_create(ver)` | `(tuya:create ver)` |
| *(constructor stores creds)* | `tuya_set_credentials(dev, id, key)` | `(tuya:set-credentials dev id key)` |
| *(constructor connects)* | `tuya_connect(dev, addr)` | `(tuya:connect dev addr)` |
| *(auto for 3.4+)* | `tuya_negotiate_session(dev, key)` | `(tuya:negotiate-session dev key)` |
| `d.close()` | `tuya_disconnect(dev)` | `(tuya:disconnect dev)` |
| *(del d)* | `tuya_destroy(dev)` | `(tuya:destroy dev)` |

**High-level operations (full round-trip):**

| tinytuya (Python) | seatuya (C) | seatuya (newLISP) |
|--------------------|-------------|---------------------|
| `d.turn_on(switch)` | `tuya_turn_on(dev, dp)` | `(tuya:turn-on dev dp)` |
| `d.turn_off(switch)` | `tuya_turn_off(dev, dp)` | `(tuya:turn-off dev dp)` |
| `d.set_value(dp, value)` | `tuya_set_value_bool(dev, dp, val)` | `(tuya:set-value dev dp val)` |
| | `tuya_set_value_int(dev, dp, val)` | *(type auto-detected)* |
| | `tuya_set_value_string(dev, dp, val)` | |
| | `tuya_set_value_float(dev, dp, val)` | |
| `d.status()` | `tuya_status(dev)` | `(tuya:status dev)` |
| `d.heartbeat()` | `tuya_heartbeat(dev)` | `(tuya:heartbeat dev)` |
| *(reconnect logic in set_status)* | `tuya_reconnect(dev)` | `(tuya:reconnect dev)` |

**Credential and state getters:**

| tinytuya (Python) | seatuya (C) | seatuya (newLISP) |
|--------------------|-------------|---------------------|
| `d.id` | `tuya_get_device_id(dev)` | `(tuya:get-device-id dev)` |
| `d.local_key` | `tuya_get_local_key(dev)` | `(tuya:get-local-key dev)` |
| `d.address` | `tuya_get_ip(dev)` | `(tuya:get-ip dev)` |
| *(n/a)* | `tuya_get_protocol(dev)` | `(tuya:get-protocol dev)` |
| *(n/a)* | `tuya_get_session_state(dev)` | `(tuya:get-session-state dev)` |
| *(n/a)* | `tuya_get_socket_state(dev)` | `(tuya:get-socket-state dev)` |
| *(n/a)* | `tuya_get_last_error(dev)` | `(tuya:get-last-error dev)` |

**Low-level (no tinytuya equivalent -- for pipelining or custom commands):**

| seatuya (C) | seatuya (newLISP) |
|-------------|---------------------|
| `tuya_generate_payload(dev, cmd, id, dps)` | `(tuya:generate-payload dev cmd id dps)` |
| `tuya_build_message(dev, buf, cmd, payload, key)` | `(tuya:build-message dev cmd payload key)` |
| `tuya_send(dev, buf, size)` | `(tuya:send dev buf)` |
| `tuya_receive(dev, buf, max, min)` | `(tuya:receive dev)` |
| `tuya_decode_message(dev, buf, size, key)` | `(tuya:decode-message dev buf key)` |
| `tuya_free_string(str)` | *(automatic)* |

tinytuya's `set_value` accepts any Python type and serializes it.
The C API splits this into four typed functions because C has no
dynamic typing.  The newLISP wrapper re-unifies them: `tuya:set-value`
inspects the value and dispatches to the right C function.

All `char *` returns from C are `malloc`'d.  C callers free them with
`tuya_free_string()`.  The newLISP wrapper copies the string and frees
the original automatically.

### Architectural difference

tinytuya bundles connection management, credentials, message framing,
and device semantics into a single `Device` object.  seatuya splits
these across two layers:

1. **`libseatuya` (C)** -- transport, encryption, framing, credential
   storage, and high-level round-trip operations (`tuya_set_value_*`,
   `tuya_status`, `tuya_turn_on`, etc.).  Equivalent to
   tinytuya's base `Device`.
2. **`tuya-devices.lsp` (FOOP classes)** -- DP mappings and named
   methods.  Equivalent to tinytuya's device subclasses.

`seatuya.lsp` is a thin FFI wrapper that imports the C functions into
newLISP.  It adds no logic of its own beyond type dispatch in
`tuya:set-value`.

The FOOP objects are plain lists.  You can always reach through to the
raw handle with `(my-device 1)` and call `tuya:` functions directly --
the abstraction is a convenience, not a cage.

### Supported device types

| Class | tinytuya equivalent | Key methods |
|-------|---------------------|-------------|
| `OutletDevice` | `OutletDevice` (core) | `:turn-on`, `:turn-off`, `:set-dimmer` |
| `BulbDevice` | `BulbDevice` (core) | `:set-colour`, `:set-brightness-pct`, `:set-colourtemp-pct`, `:set-white` |
| `CoverDevice` | `CoverDevice` (core) | `:open-cover`, `:close-cover`, `:stop-cover`, `:set-position` |
| `ThermostatDevice` | `ThermostatDevice` (contrib) | `:set-temperature`, `:set-mode`, `:get-temperature` |
| `SocketDevice` | `SocketDevice` (contrib) | `:turn-on`, `:turn-off`, `:get-energy` |
| `ClimateDevice` | `ClimateDevice` (contrib) | `:set-temperature`, `:set-mode`, `:set-fan-speed` |
| `DoorbellDevice` | `DoorbellDevice` (contrib) | `:set-volume`, `:set-motion-switch`, `:set-motion-sensitivity` |
| `IRRemoteControlDevice` | `IRRemoteControlDevice` (contrib) | `:study-start`, `:study-end`, `:send-button`, `:send-key` |
| `InverterHeatPumpDevice` | `InverterHeatPumpDevice` (contrib) | `:set-target-temp`, `:set-silence-mode`, `:get-inlet-temp` |
| `PresenceDetectorDevice` | `PresenceDetectorDevice` (contrib) | `:set-sensitivity`, `:set-near-detection`, `:set-far-detection` |

All classes also support `:status` (query all DPs), `:reconnect`
(re-establish a dropped connection, including session negotiation
for protocol 3.4+), and `:destroy` (disconnect and free the handle).

### Example: smart plug

```newlisp
(load "tuya-devices.lsp")

(setq plug (OutletDevice "3.3" "192.168.1.50" "device-id" "local-key"))
(:turn-on plug)
(:status plug)
(:turn-off plug)
(:destroy plug)
```

### Example: RGB bulb

```newlisp
(setq bulb (BulbDevice "3.4" "192.168.1.51" "device-id" "local-key"))
(:turn-on bulb)
(:set-colour bulb 255 0 0)      ; red
(:set-brightness-pct bulb 50)   ; half brightness
(:set-white bulb 500 500)       ; white mode, mid brightness + temp
(:destroy bulb)
```

### Example: thermostat with custom DP map

```newlisp
;; Default DPs: 1=switch, 2=target, 3=current, 4=mode, scale=10
;; Override for a device that uses different DP numbers:
(setq therm (ThermostatDevice "3.3" "192.168.1.52" "dev-id" "key"
              2 16 24 4 1))     ; switch=2, target=16, current=24, mode=4, scale=1
(:set-temperature therm 72)
(:get-temperature therm)        ; reads current temp from device
(:destroy therm)
```

### Example: Inkbird sous vide (custom DP map)

The `sousvide-ramp.lsp` example uses `ThermostatDevice` with Inkbird's
non-standard DP numbers (101-110 instead of the usual 1-4):

```newlisp
(setq sv (ThermostatDevice version ip device-id local-key
           101 103 104 102 10))   ; power=101, target=103, current=104, status=102, scale=10
(power-on sv)                     ; wrapper around (:turn-on sv)
(set-temperature-f sv 145.0)      ; wrapper: F->C conversion, then (:set-temperature sv celsius)
(query-status sv)                 ; wrapper around (:status sv)
(:destroy sv)
```

The named wrappers (`power-on`, `set-temperature-f`, `query-status`)
are application-level functions that call the FOOP methods, which call
`tuya:set-value`, which calls the raw FFI.  Each layer hides the right
details: the FOOP class hides DP numbers, the convenience functions
hide temperature conversion, the FFI wrapper hides buffers.

### DP number customization

Every constructor accepts optional DP number overrides for devices that
use non-standard mappings.  The defaults match the most common Tuya
device configurations, as documented by tinytuya.

## License

BSD-2-Clause.  See `COPYING` for details.

tuyapp is licensed under GPL-3.0+ (see `deps/tuyapp/LICENSE` after fetch).
jsoncpp is licensed under MIT (see `deps/jsoncpp/LICENSE` after fetch).
