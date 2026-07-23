# Emacs Lisp FFI Bindings for libseatuya

Emacs 28+ FFI binding using the `emacs-ffi` package for pure-Lisp
dynamic C interop.  M-x tuya-turn-on is now a thing.  Falls back
to a native module for older Emacs versions.

## Prerequisites
- Emacs 28+ or `M-x package-install RET emacs-ffi RET`
- libseatuya installed

## Usage
```elisp
(load-file "seatuya.el")
(setq dev (seatuya-create id "192.168.1.100" key "3.4"))
(message "%s" (seatuya-turn-on dev 1))
(seatuya-destroy dev)
```

Run: `emacs --script example.el`
