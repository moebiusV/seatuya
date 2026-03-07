; libtls.lsp — newLISP module wrapping libtls (LibreSSL/libretls).
;
; Provides HTTPS client functionality via the libtls API.
; Loads crypto.lsp for all cryptographic operations (hashing,
; HMAC, PBKDF2, CSPRNG, hex encoding).
;
; Usage:
;   (load "libtls.lsp")
;   (tls:request "example.com" "GET" "/api/v1/foo"
;                '(("Authorization" "Bearer xyz")) nil)
;   => response body string or nil
;
; The tls context sets tls:available? to true/nil.
; Callers can check this and call (tls:install-hint) for guidance.
;

;; ----------------------------------------------------------------
;;  Load crypto.lsp (complete libcrypto wrapper)
;; ----------------------------------------------------------------

(let (dir (or (env "SEATUYA_LSP_DIR") (real-path ".")))
  (load (string dir "/crypto.lsp")))

;; ----------------------------------------------------------------
;;  libtls FFI (context: tls)
;; ----------------------------------------------------------------

(context 'tls)

;; ---- library discovery ----

;; ---- library discovery ----

(constant 'LIB_BASE
  (if (= ostype "OSX") "libtls.dylib" "libtls.so"))

(setq LIB (find-lib:locate LIB_BASE "tls_init"))

(setq available? (if LIB true nil))

(define (install-hint)
  "Print a distro-specific install hint for libtls."
  (println "error: libtls not found.")
  (println)
  (println "libtls provides a clean TLS API from LibreSSL. To install it:")
  (println)
  (cond
    ((file? "/etc/os-release")
     (let (id "")
       (dolist (line (parse (read-file "/etc/os-release") "\n"))
         (when (starts-with line "ID=")
           (setq id (trim (replace "\"" (slice line 3) "") " "))))
       (cond
         ((find id '("ubuntu" "debian" "linuxmint" "pop" "elementary" "kali" "raspbian"))
          (println "  sudo apt-get install libtls-dev"))
         ((= id "fedora")
          (println "  sudo dnf install libretls-devel"))
         ((find id '("rhel" "centos" "rocky" "alma"))
          (println "  sudo dnf install libretls-devel    (from EPEL)"))
         ((starts-with id "opensuse")
          (println "  sudo zypper install libretls-devel"))
         ((find id '("arch" "manjaro" "endeavouros" "artix" "garuda"))
          (println "  sudo pacman -S libressl"))
         ((= id "alpine")
          (println "  apk add libretls-dev"))
         ((= id "gentoo")
          (println "  sudo emerge dev-libs/libretls"))
         ((= id "void")
          (println "  sudo xbps-install libretls-devel"))
         ((= id "nixos")
          (println "  nix-env -iA nixpkgs.libretls"))
         ((= id "slackware")
          (println "  Install libtls from SlackBuilds.org"))
         (true
          (println "  Install libretls or libressl from your package manager.")))))
    ((= ostype "OSX")
     (println "  brew install libressl"))
    (true
     (println "  Install libretls or libressl from your package manager.")))
  (println))

;; If libtls wasn't found, stop here.
;; Callers check tls:available? and call (tls:install-hint) themselves.
(unless LIB
  (context MAIN))

(when LIB
  ;; ---- libtls FFI imports ----

  (import LIB "tls_init")
  (import LIB "tls_config_new")
  (import LIB "tls_config_free")
  (import LIB "tls_client")
  (import LIB "tls_configure")
  (import LIB "tls_connect")
  (import LIB "tls_handshake")
  (import LIB "tls_write")
  (import LIB "tls_read")
  (import LIB "tls_close")
  (import LIB "tls_free")
  (import LIB "tls_error")

  (constant 'WANT_POLLIN  -2)
  (constant 'WANT_POLLOUT -3)

  (tls_init)

  ;; ---- HTTPS request ----

  (define (request host method path headers body)
    "Make an HTTPS request via libtls.
     host    — hostname (e.g. \"api.example.com\")
     method  — HTTP method (\"GET\", \"POST\", etc.)
     path    — URL path (e.g. \"/v1.0/token\")
     headers — list of (key value) pairs, or nil
     body    — request body string, or nil
     Returns the response body (everything after HTTP headers) as a string,
     or nil on error."
    (let (cfg (tls_config_new))
      (unless (!= cfg 0)
        (println "error: tls_config_new failed")
        (throw nil))
      (let (ctx (tls_client))
        (unless (!= ctx 0)
          (tls_config_free cfg)
          (println "error: tls_client failed")
          (throw nil))
        (tls_configure ctx cfg)
        (tls_config_free cfg)
        (when (< (tls_connect ctx host "443") 0)
          (println "error: TLS connection to " host " failed: "
                   (get-string (tls_error ctx)))
          (tls_free ctx)
          (throw nil))
        (when (< (tls_handshake ctx) 0)
          (println "error: TLS handshake with " host " failed: "
                   (get-string (tls_error ctx)))
          (tls_free ctx)
          (throw nil))

        ;; Build HTTP request
        (let (req (string method " " path " HTTP/1.1\r\n"
                          "Host: " host "\r\n"))
          (when headers
            (dolist (h headers)
              (setq req (string req (h 0) ": " (h 1) "\r\n"))))
          (when (and body (!= body ""))
            (setq req (string req "Content-Length: " (length body) "\r\n")))
          (setq req (string req "Connection: close\r\n\r\n"))
          (when (and body (!= body ""))
            (setq req (string req body)))

          ;; Send
          (let (off 0 total (length req))
            (while (< off total)
              (let (w (tls_write ctx (slice req off) (- total off)))
                (cond
                  ((or (= w WANT_POLLIN) (= w WANT_POLLOUT)) nil)
                  ((< w 0)
                   (println "error: tls_write: " (get-string (tls_error ctx)))
                   (tls_free ctx)
                   (throw nil))
                  (true (inc off w))))))

          ;; Receive
          (let (resp "" buf (dup "\000" 4096))
            (catch
              (while true
                (let (rd (tls_read ctx buf 4096))
                  (cond
                    ((or (= rd WANT_POLLIN) (= rd WANT_POLLOUT)) nil)
                    ((<= rd 0) (throw true))
                    (true (setq resp (string resp (slice buf 0 rd))))))))
            (tls_close ctx)
            (tls_free ctx)

            ;; Strip HTTP headers, return body
            (let (hdr-end (find "\r\n\r\n" resp))
              (when hdr-end
                (slice resp (+ hdr-end 4)))))))))

  (define (request-json host method path headers body)
    "Like request, but extracts the first JSON object from the response body."
    (let (resp (request host method path headers body))
      (when resp
        (let (start (find "{" resp))
          (when start
            (slice resp start))))))

) ; end (when LIB ...)

(context MAIN)
