# Common Lisp CFFI Bindings for libseatuya

Portable Common Lisp binding using [CFFI](https://common-lisp.net/project/cffi/).
Tested with **SBCL** and **ECL** — works with any implementation CFFI supports
(CCL, Allegro, LispWorks, ABCL).

## Prerequisites

```common-lisp
(ql:quickload :cffi)
```

libseatuya must be installed (`make install`).

## Usage

```common-lisp
(load "seatuya.lisp")

(defvar dev (seatuya:create device-id "192.168.1.100" local-key "3.4"))

(format t "~A~%" (seatuya:turn-on dev 1))
(format t "~A~%" (seatuya:status dev))
(format t "~A~%" (seatuya:turn-off dev 1))

(seatuya:destroy dev)
```

Run with SBCL: `sbcl --script example.lisp`
Run with ECL: `ecl --load example.lisp`

## API

See the [seatuya(3)](../../seatuya.3) manpage.  All functions are in the
`:seatuya` package.  Constants use `+name+` convention.  Type dispatch
in `set-value` uses `typecase`.
