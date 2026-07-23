# Fortran ISO_C_BINDING for libseatuya

Standard Fortran 2003+ binding using `iso_c_binding` and `bind(c)`.
Every C function is declared in an interface block with proper types.
String conversion (C→Fortran) and auto-free of malloc'd strings handled.

## Prerequisites
- gfortran 4.3+, ifort 11+, or any Fortran 2003 compiler
- libseatuya installed

## Build
```sh
gfortran -lseatuya seatuya.f90 example.f90 -o example
```

## Usage
```fortran
use seatuya
dev = seatuya_create("id", "192.168.1.100", "key", "3.4")
print *, seatuya_turn_on(dev, 1)
call seatuya_destroy(dev)
```
