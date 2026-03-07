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
seatuya installed, a 200-line FFI wrapper (seatuya.lsp) gives it the
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
   prove this: 200 lines of FFI wrapping, and a language with zero
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
(tuya:connect dev "192.168.1.100")
(tuya:negotiate-session dev local-key)

; turn on switch (data point 1)
(setq payload (tuya:generate-payload dev tuya:CMD_CONTROL device-id "{\"1\":true}"))
(setq msg     (tuya:build-message dev tuya:CMD_CONTROL payload local-key))
(tuya:send dev msg)

; read response
(setq raw (tuya:receive dev))
(println (tuya:decode-message dev raw local-key))

(tuya:destroy dev)
```

No buffer management, no byte counting, no pointer arithmetic.
The wrapper handles all of that.  `build-message` allocates and
returns the right number of bytes; `receive` returns a sized buffer
or nil; `decode-message` copies the C string and frees the original.
The constants (`CMD_CONTROL`, `CMD_DP_QUERY`, etc.) are real values
extracted from the C header, not `#define` macros that had to be
copied by hand.

The same approach works in Python ctypes, Lua FFI, Ruby FFI, Tcl,
Zig, Nim, Racket, Janet, or anything else that can call C functions.
`seatuya.lsp` is 200 lines.  A wrapper in your language of choice
would be about the same.

## License

BSD-2-Clause.  See `COPYING` for details.

tuyapp is licensed under GPL-3.0+ (see `deps/tuyapp/LICENSE` after fetch).
jsoncpp is licensed under MIT (see `deps/jsoncpp/LICENSE` after fetch).
