# GnuCOBOL FFI Bindings for libseatuya

GnuCOBOL (formerly OpenCOBOL) binding using `CALL STATIC` with
`LINKAGE SECTION` declarations.  The opaque `tuya_device_t*` is
stored as a COBOL `USAGE POINTER`.

## Prerequisites
- GnuCOBOL 3.1+ (`cobc`)
- libseatuya installed

## Build
```sh
cobc -x -lseatuya seatuya.cbl example.cbl -o example
```

## Usage
```cobol
CALL "seatuya-create" USING device-id ip local-key version
    RETURNING dev
CALL "seatuya-turn-on" USING dev 1 RETURNING json
CALL "seatuya-destroy" USING dev
```

COBOL can call C; COBOL programmers deserve IoT too.
