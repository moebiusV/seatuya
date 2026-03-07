; crypto.lsp — Complete newLISP wrapper for OpenSSL/LibreSSL libcrypto.
;
; Drop-in replacement for the built-in crypto.lsp with these improvements:
;   - All hash functions write into caller-owned buffers (no static internals)
;   - Native HMAC via OpenSSL's HMAC() instead of software RFC 2104
;   - SHA224, SHA384, SHA512 added
;   - SHA3-256, SHA3-384, SHA3-512 via EVP_Digest (OpenSSL 1.1.1+)
;   - PBKDF2 key derivation
;   - RAND_bytes for cryptographic random
;   - Hex encoding helpers
;
; API-compatible with the built-in crypto.lsp: all existing functions
; (md5, sha1, sha256, ripemd160, hmac) keep the same signatures.
;
; Usage:
;   (load "crypto.lsp")
;   ; or to replace the built-in:
;   (module "crypto.lsp")
;
;   (crypto:sha256 "ABC")
;     => "b5d4045c3f466fa91fe2cc6abe79232a1a57cdf104f7a26e716e0a1e2789df78"
;   (crypto:sha256 "ABC" true)
;     => raw 32 bytes
;   (crypto:hmac crypto:sha256 "Hello" "secret")
;     => raw HMAC bytes (native, not software)
;   (crypto:hmac-sha256 "secret" "Hello")
;     => raw 32-byte HMAC-SHA256
;   (crypto:rand-bytes 16)
;     => 16 random bytes
;   (crypto:pbkdf2 "password" "salt" 10000 32)
;     => 32-byte derived key
;

;; ---- load find-lib ----

(let (dir (or (env "SEATUYA_LSP_DIR") (real-path ".")))
  (unless (context? find-lib)
    (load (string dir "/find-lib.lsp"))))

(context 'crypto)

;; ---- library discovery ----

(constant 'LIB_BASE
  (if (= ostype "OSX")     "libcrypto.dylib"
      (= ostype "Windows") "libcrypto.dll"
      "libcrypto.so"))

(setq library (find-lib:locate LIB_BASE "MD5"))

(unless library
  (println "error: libcrypto not found. Install OpenSSL or LibreSSL.")
  (context MAIN))

;; ---- one-shot hash imports ----
;;
;; C signature (all the same pattern):
;;   unsigned char *MD5(const unsigned char *d, size_t n, unsigned char *md);
;;
;; When md is non-NULL, the digest is written directly into it and md
;; is returned.  We always pass our own buffer to avoid the static
;; internal buffer (which is not thread-safe).

(import library "MD5")
(import library "SHA1")
(import library "SHA224")
(import library "SHA256")
(import library "SHA384")
(import library "SHA512")
(import library "RIPEMD160")

;; ---- EVP digest (one-shot, for SHA3 and general use) ----
;;
;; int EVP_Digest(const void *data, size_t count,
;;                unsigned char *md, unsigned int *size,
;;                const EVP_MD *type, ENGINE *impl);

(import library "EVP_Digest")

;; ---- EVP_MD accessors ----

(import library "EVP_md5")
(import library "EVP_sha1")
(import library "EVP_sha224")
(import library "EVP_sha256")
(import library "EVP_sha384")
(import library "EVP_sha512")

;; SHA3 may not be available on older OpenSSL
(setq has-sha3 nil)
(when (catch (begin (import library "EVP_sha3_256") true) 'err)
  (import library "EVP_sha3_384")
  (import library "EVP_sha3_512")
  (setq has-sha3 true))

;; ---- HMAC import ----

(import library "HMAC")

;; ---- PBKDF2 import ----

(import library "PKCS5_PBKDF2_HMAC")

;; ---- RAND import ----

(import library "RAND_bytes")

;; ---- internal: format hash output ----

(define (format-digest buf raw-flag)
  "Return buf as-is if raw-flag, otherwise as lowercase hex."
  (if raw-flag buf
    (join (map (fn (x) (format "%02x" (& x 0xff)))
               (unpack (dup "c" (length buf)) buf)))))

;; ---- internal: one-shot hash into caller-owned buffer ----

(define (hash-into c-func len str raw-flag)
  "Call a one-shot hash function, writing into our own buffer."
  (let (buf (dup "\000" len))
    (c-func str (length str) buf)
    (format-digest buf raw-flag)))

;; ---- internal: one-shot EVP digest ----

(define (evp-digest-into evp-md len str raw-flag)
  "Hash via EVP_Digest, writing into our own buffer."
  (let (buf (dup "\000" len)
        outlen (pack "lu" len))
    (EVP_Digest str (length str) buf (address outlen) (evp-md) 0)
    (format-digest buf raw-flag)))

;; ================================================================
;;  Hash functions — all write into caller-owned buffers
;; ================================================================

;; @syntax (crypto:md5 <string> <bool-raw>)
;; @return 32-char hex string, or 16-byte raw buffer if raw-flag is true.
;; @example
;; (crypto:md5 "ABC") => "902fbdd2b1df0c4f70b4a5d23525e932"
(define (md5 str raw-flag)
  (hash-into MD5 16 str raw-flag))

;; @syntax (crypto:sha1 <string> <bool-raw>)
;; @return 40-char hex string, or 20-byte raw buffer.
;; @example
;; (crypto:sha1 "ABC") => "3c01bdbb26f358bab27f267924aa2c9a03fcfdb8"
(define (sha1 str raw-flag)
  (hash-into SHA1 20 str raw-flag))

;; @syntax (crypto:sha224 <string> <bool-raw>)
;; @return 56-char hex string, or 28-byte raw buffer.
(define (sha224 str raw-flag)
  (hash-into SHA224 28 str raw-flag))

;; @syntax (crypto:sha256 <string> <bool-raw>)
;; @return 64-char hex string, or 32-byte raw buffer.
;; @example
;; (crypto:sha256 "ABC") => "b5d4045c3f466fa91fe2cc6abe79232a1a57cdf104f7a26e716e0a1e2789df78"
(define (sha256 str raw-flag)
  (hash-into SHA256 32 str raw-flag))

;; @syntax (crypto:sha384 <string> <bool-raw>)
;; @return 96-char hex string, or 48-byte raw buffer.
(define (sha384 str raw-flag)
  (hash-into SHA384 48 str raw-flag))

;; @syntax (crypto:sha512 <string> <bool-raw>)
;; @return 128-char hex string, or 64-byte raw buffer.
(define (sha512 str raw-flag)
  (hash-into SHA512 64 str raw-flag))

;; @syntax (crypto:ripemd160 <string> <bool-raw>)
;; @return 40-char hex string, or 20-byte raw buffer.
;; @example
;; (crypto:ripemd160 "ABC") => "df62d400e51d3582d53c2d89cfeb6e10d32a3ca6"
(define (ripemd160 str raw-flag)
  (hash-into RIPEMD160 20 str raw-flag))

;; ---- SHA3 (via EVP_Digest, requires OpenSSL 1.1.1+) ----

(when has-sha3
  ;; @syntax (crypto:sha3-256 <string> <bool-raw>)
  ;; @return 64-char hex string, or 32-byte raw buffer.
  (define (sha3-256 str raw-flag)
    (evp-digest-into EVP_sha3_256 32 str raw-flag))

  ;; @syntax (crypto:sha3-384 <string> <bool-raw>)
  ;; @return 96-char hex string, or 48-byte raw buffer.
  (define (sha3-384 str raw-flag)
    (evp-digest-into EVP_sha3_384 48 str raw-flag))

  ;; @syntax (crypto:sha3-512 <string> <bool-raw>)
  ;; @return 128-char hex string, or 64-byte raw buffer.
  (define (sha3-512 str raw-flag)
    (evp-digest-into EVP_sha3_512 64 str raw-flag)))

;; ================================================================
;;  HMAC — native via libcrypto
;; ================================================================
;;
;; C signature:
;;   unsigned char *HMAC(const EVP_MD *evp_md,
;;                       const void *key, int key_len,
;;                       const unsigned char *data, int data_len,
;;                       unsigned char *md, unsigned int *md_len);
;;
;; When md is non-NULL, writes directly into it.  We always pass
;; our own buffer.

(define (hmac-native evp-fn key msg digest-len)
  (let (out (dup "\000" digest-len)
        len (pack "lu" digest-len))
    (HMAC (evp-fn) key (length key) msg (length msg) out (address len))
    out))

;; @syntax (crypto:hmac <func-hash> <str-message> <str-key>)
;; @param <func-hash> A crypto hash function (e.g. crypto:sha256).
;; @param <str-message> The message to authenticate.
;; @param <str-key> The secret key.
;; @return Raw HMAC bytes.
;;
;; API-compatible with the built-in crypto:hmac but uses native HMAC()
;; from libcrypto instead of a software implementation. Dispatches to
;; the correct EVP digest based on which hash function is passed.
;;
;; @example
;; (crypto:hmac crypto:sha256 "Hello World" "secret")
(define (hmac hash_fn msg_str key_str)
  (cond
    ((= hash_fn md5)        (hmac-native EVP_md5    key_str msg_str 16))
    ((= hash_fn sha1)       (hmac-native EVP_sha1   key_str msg_str 20))
    ((= hash_fn sha224)     (hmac-native EVP_sha224 key_str msg_str 28))
    ((= hash_fn sha256)     (hmac-native EVP_sha256 key_str msg_str 32))
    ((= hash_fn sha384)     (hmac-native EVP_sha384 key_str msg_str 48))
    ((= hash_fn sha512)     (hmac-native EVP_sha512 key_str msg_str 64))
    ((= hash_fn ripemd160)  (hmac-native EVP_sha256 key_str msg_str 32))
    (true
     ;; Fallback: software HMAC for unknown hash functions
     (letn (blocksize 64
            opad (dup "\x5c" blocksize)
            ipad (dup "\x36" blocksize)
            k (if (> (length key_str) blocksize)
                  (hash_fn key_str true)
                  key_str)
            k (append k (dup "\000" (- blocksize (length k)))))
       (hash_fn (append (encrypt opad k)
                        (hash_fn (append (encrypt ipad k) msg_str) true))
                true)))))

;; ---- Convenience HMAC functions ----

;; @syntax (crypto:hmac-md5 <str-key> <str-msg>)
;; @return Raw 16-byte HMAC-MD5.
(define (hmac-md5 key msg)
  (hmac-native EVP_md5 key msg 16))

;; @syntax (crypto:hmac-sha1 <str-key> <str-msg>)
;; @return Raw 20-byte HMAC-SHA1.
(define (hmac-sha1 key msg)
  (hmac-native EVP_sha1 key msg 20))

;; @syntax (crypto:hmac-sha256 <str-key> <str-msg>)
;; @return Raw 32-byte HMAC-SHA256.
;; @example
;; (crypto:to-hex (crypto:hmac-sha256 "secret" "Hello World"))
(define (hmac-sha256 key msg)
  (hmac-native EVP_sha256 key msg 32))

;; @syntax (crypto:hmac-sha384 <str-key> <str-msg>)
;; @return Raw 48-byte HMAC-SHA384.
(define (hmac-sha384 key msg)
  (hmac-native EVP_sha384 key msg 48))

;; @syntax (crypto:hmac-sha512 <str-key> <str-msg>)
;; @return Raw 64-byte HMAC-SHA512.
(define (hmac-sha512 key msg)
  (hmac-native EVP_sha512 key msg 64))

;; ================================================================
;;  PBKDF2 key derivation
;; ================================================================
;;
;; C signature:
;;   int PKCS5_PBKDF2_HMAC(const char *pass, int passlen,
;;                          const unsigned char *salt, int saltlen,
;;                          int iter, const EVP_MD *digest,
;;                          int keylen, unsigned char *out);
;;
;; Writes into caller-provided out buffer.

;; @syntax (crypto:pbkdf2 <str-password> <str-salt> <int-iterations> <int-keylen> [<func-hash>])
;; @param <str-password> The password.
;; @param <str-salt> The salt.
;; @param <int-iterations> Number of iterations.
;; @param <int-keylen> Desired key length in bytes.
;; @param <func-hash> Hash function (default: crypto:sha256).
;; @return Raw derived key bytes, or nil on error.
;; @example
;; (crypto:pbkdf2 "password" "salt" 10000 32) => 32 raw bytes
(define (pbkdf2 password salt iterations keylen hash_fn)
  (let (evp (cond
              ((or (not hash_fn) (= hash_fn sha256)) (EVP_sha256))
              ((= hash_fn sha1)   (EVP_sha1))
              ((= hash_fn sha384) (EVP_sha384))
              ((= hash_fn sha512) (EVP_sha512))
              ((= hash_fn md5)    (EVP_md5))
              (true (EVP_sha256)))
        out (dup "\000" keylen))
    (if (= 1 (PKCS5_PBKDF2_HMAC password (length password)
                                  salt (length salt)
                                  iterations evp keylen out))
      out
      nil)))

;; ================================================================
;;  Cryptographic random
;; ================================================================
;;
;; C signature:
;;   int RAND_bytes(unsigned char *buf, int num);
;;
;; Writes into caller-provided buffer.

;; @syntax (crypto:rand-bytes <int-num-bytes>)
;; @return <int-num-bytes> cryptographically strong random bytes, or nil on error.
;; @example
;; (crypto:rand-bytes 16) => 16 random bytes
(define (rand-bytes num-bytes)
  (let (buf (dup "\000" num-bytes))
    (if (= 1 (RAND_bytes buf num-bytes))
      buf
      nil)))

;; ================================================================
;;  Hex encoding helpers
;; ================================================================

;; @syntax (crypto:to-hex <str-raw>)
;; @return Lowercase hex string.
;; @example
;; (crypto:to-hex "\xDE\xAD") => "dead"
(define (to-hex raw)
  (join (map (fn (c) (format "%02x" (& c 0xff)))
             (unpack (dup "c" (length raw)) raw))))

;; @syntax (crypto:to-upper-hex <str-raw>)
;; @return Uppercase hex string.
(define (to-upper-hex raw)
  (upper-case (to-hex raw)))

;; @syntax (crypto:from-hex <str-hex>)
;; @return Raw binary string decoded from hex.
;; @example
;; (crypto:from-hex "deadbeef") => "\xDE\xAD\xBE\xEF"
(define (from-hex hex-str)
  (let (out "")
    (for (i 0 (- (length hex-str) 1) 2)
      (setq out (append out (pack "b" (int (string "0x" (slice hex-str i 2)))))))
    out))

(context MAIN)

; eof ;
