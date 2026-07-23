# GNU Guile FFI Bindings for libseatuya

Pure Guile Scheme binding using the built-in `(system foreign)` module.
Guile's dynamic FFI is part of the core — no packages needed.

## Prerequisites

- GNU Guile 2.2+
- libseatuya installed (`make install`)

## Usage

```scheme
(use-modules (seatuya))

(define dev (seatuya-create device-id "192.168.1.100" local-key "3.4"))
(format #t "~A~%" (seatuya-turn-on dev 1))
(format #t "~A~%" (seatuya-status dev))
(seatuya-destroy dev)
```

Run: `guile -L . example.scm`

## API

See the [seatuya(3)](../../seatuya.3) manpage.  All functions prefixed
with `seatuya-` and use kebab-case.  Bytevectors used for buffer
operations.  Constants exported as symbols.
