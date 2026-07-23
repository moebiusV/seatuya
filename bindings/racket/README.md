# Racket FFI Bindings for libseatuya

Pure Racket binding using the built-in `ffi/unsafe` module.
Racket's FFI is part of the core — no packages needed.

## Prerequisites

- Racket 8.0+
- libseatuya installed (`make install`)

## Usage

```racket
#lang racket
(require "seatuya.rkt")

(define dev (seatuya-create device-id "192.168.1.100" local-key "3.4"))
(printf "~A~%" (seatuya-turn-on dev 1))
(printf "~A~%" (seatuya-status dev))
(seatuya-destroy dev)
```

Run: `racket example.rkt`

## API

See the [seatuya(3)](../../seatuya.3) manpage.  All functions prefixed
with `seatuya-` in kebab-case.  Uses `define-ffi-definer` for concise
function declarations.  Constants provided as identifiers.
