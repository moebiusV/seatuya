; find-lib.lsp — Shared library discovery for newLISP FFI modules.
;
; Searches known directories for a shared library by base name,
; tries the unversioned name first (symlink to latest), then globs
; for versioned .so.N files and tries the highest version number.
;
; Usage:
;   (load "find-lib.lsp")
;   (find-lib:locate "libcrypto.so" "MD5")        => "/usr/lib/x86_64-linux-gnu/libcrypto.so.3"
;   (find-lib:locate "libtls.dylib" "tls_init")   => "/usr/local/opt/libressl/lib/libtls.dylib"
;
; Returns the library path string on success, nil if not found.
; The probe-symbol argument is imported as a side effect of discovery.

(context 'find-lib)

;; Directories to search, per platform.
;; Covers Debian multiarch, Red Hat /usr/lib64, Homebrew on Intel
;; and Apple Silicon Macs, FreeBSD /usr/local, OpenBSD and NetBSD
;; /usr/pkg, and NixOS /run/current-system/sw/lib.

(constant 'SEARCH_DIRS
  (if (= ostype "OSX")
      '("/opt/homebrew/lib"
        "/opt/homebrew/opt/openssl/lib"
        "/opt/homebrew/opt/openssl@3/lib"
        "/opt/homebrew/opt/openssl@1.1/lib"
        "/opt/homebrew/opt/libressl/lib"
        "/usr/local/opt/openssl/lib"
        "/usr/local/opt/openssl@3/lib"
        "/usr/local/opt/openssl@1.1/lib"
        "/usr/local/opt/libressl/lib"
        "/usr/local/lib"
        "/usr/lib")
      ;; Unix / Linux / BSD
      '("/usr/lib/x86_64-linux-gnu"
        "/usr/lib/aarch64-linux-gnu"
        "/usr/lib/i386-linux-gnu"
        "/usr/lib/arm-linux-gnueabihf"
        "/usr/lib64"
        "/usr/lib"
        "/lib/x86_64-linux-gnu"
        "/lib64"
        "/lib"
        "/usr/local/lib"
        "/usr/pkg/lib"
        "/run/current-system/sw/lib")))

(define (version-sort-key path base)
  "Extract numeric version suffix.  Unversioned => 999 (highest priority)."
  (if (ends-with path base)
      999
      (let (escaped (join (parse base ".") "\\.")
            pat     (string escaped "\\.(.+)$")
            m       (find pat path 0))
        (if m (float $1) 0))))

(define (find-versioned dir base)
  "List all variants of base in dir, sorted highest version first."
  (let (found '())
    (when (directory? dir)
      (dolist (f (directory dir))
        (when (starts-with f base)
          (push (string dir "/" f) found -1)))
      (sort found (fn (a b) (> (version-sort-key a base)
                                (version-sort-key b base)))))
    found))

(define (try-import lib-name func-name)
  "Attempt to import func-name from lib-name.  Returns lib-name on success, nil on failure."
  (when (catch (begin (import lib-name func-name) lib-name) 'err)
    lib-name))

(define (locate base probe-sym , result)
  "Find a shared library by base name (e.g. \"libcrypto.so\").
   probe-sym is a symbol name used to test that the library loads
   (e.g. \"MD5\" or \"tls_init\").
   Returns the library path on success, nil if not found."
  ;; Try the bare name first (uses ld.so / dyld search path)
  (setq result (try-import base probe-sym))
  (unless result
    ;; Scan each directory
    (catch
      (dolist (dir SEARCH_DIRS)
        (dolist (path (find-versioned dir base))
          (when (try-import path probe-sym)
            (setq result path)
            (throw true))))))
  ;; Windows legacy fallback
  (when (and (not result) (= ostype "Windows") (= base "libcrypto.dll"))
    (setq result (try-import "libeay32.dll" probe-sym)))
  result)

(context MAIN)

; eof ;
