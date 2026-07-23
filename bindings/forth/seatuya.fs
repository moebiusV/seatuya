\ seatuya.fs -- gforth FFI bindings for libseatuya
\
\ Uses gforth's c-library with embedded C wrappers for dynamic
\ library loading via dlopen/dlsym and auto-consumption of
\ malloc'd C strings (strdup+free in the wrapper).
\
\ Usage:
\   require seatuya.fs
\   s" libseatuya.so" seatuya-init
\   s" devid" s" 1.2.3.4" s" key" s" 3.4" tuya-create
\
\ Set SEATUYA_LIB env var for custom library path.

c-library seatuya

\c #define _GNU_SOURCE
\c #include <dlfcn.h>
\c #include <string.h>
\c #include <stdbool.h>
\c
\c typedef struct tuya_device tuya_device_t;
\c
\c static void *lib_handle = NULL;
\c
\c static void *dlsym_seatuya(const char *name) {
\c     if (!lib_handle) {
\c         const char *env = getenv("SEATUYA_LIB");
\c         if (!env || !*env) env = "libseatuya.so";
\c         lib_handle = dlopen(env, RTLD_LAZY | RTLD_LOCAL);
\c         if (!lib_handle) {
\c             fprintf(stderr, "seatuya: dlopen failed: %s\n", dlerror());
\c         }
\c     }
\c     return lib_handle ? dlsym(lib_handle, name) : NULL;
\c }
\c
\c /* Helper: consume a malloc'd C string (copy + free original) */
\c static char *consume(char *s) {
\c     char *c = s ? strdup(s) : NULL;
\c     if (s) {
\c         typedef void (*ff)(char*);
\c         static ff free_fn = NULL;
\c         if (!free_fn) free_fn = (ff)dlsym_seatuya("tuya_free_string");
\c         if (free_fn) free_fn(s);
\c     }
\c     return c;
\c }
\c
\c /* --- Wrappers that dlopen/dlsym each function lazily --- */
\c
\c const char *w_tuya_version(void) {
\c     typedef const char*(*fn)(void);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_version"))) return NULL;
\c     return f();
\c }
\c
\c tuya_device_t *w_tuya_create(const char *a, const char *b,
\c                               const char *c, const char *d) {
\c     typedef tuya_device_t*(*fn)(const char*,const char*,const char*,const char*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_create"))) return NULL;
\c     return f(a,b,c,d);
\c }
\c
\c tuya_device_t *w_tuya_alloc(const char *v) {
\c     typedef tuya_device_t*(*fn)(const char*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_alloc"))) return NULL;
\c     return f(v);
\c }
\c
\c void w_tuya_destroy(tuya_device_t *d) {
\c     typedef void(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_destroy"))) return;
\c     f(d);
\c }
\c
\c void w_set_creds(tuya_device_t *d, const char *id, const char *k) {
\c     typedef void(*fn)(tuya_device_t*,const char*,const char*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_set_credentials"))) return;
\c     f(d,id,k);
\c }
\c
\c const char *w_get_devid(tuya_device_t *d) {
\c     typedef const char*(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_get_device_id"))) return NULL;
\c     return f(d);
\c }
\c
\c const char *w_get_key(tuya_device_t *d) {
\c     typedef const char*(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_get_local_key"))) return NULL;
\c     return f(d);
\c }
\c
\c const char *w_get_ip(tuya_device_t *d) {
\c     typedef const char*(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_get_ip"))) return NULL;
\c     return f(d);
\c }
\c
\c bool w_connect(tuya_device_t *d, const char *h) {
\c     typedef bool(*fn)(tuya_device_t*,const char*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_connect"))) return false;
\c     return f(d,h);
\c }
\c
\c void w_disconnect(tuya_device_t *d) {
\c     typedef void(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_disconnect"))) return;
\c     f(d);
\c }
\c
\c bool w_is_connected(tuya_device_t *d) {
\c     typedef bool(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_is_connected"))) return false;
\c     return f(d);
\c }
\c
\c bool w_reconnect(tuya_device_t *d) {
\c     typedef bool(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_reconnect"))) return false;
\c     return f(d);
\c }
\c
\c void w_set_retry_limit(tuya_device_t *d, int n) {
\c     typedef void(*fn)(tuya_device_t*,int);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_set_retry_limit"))) return;
\c     f(d,n);
\c }
\c void w_set_retry_delay(tuya_device_t *d, int n) {
\c     typedef void(*fn)(tuya_device_t*,int);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_set_retry_delay"))) return;
\c     f(d,n);
\c }
\c int w_get_retry_limit(tuya_device_t *d) {
\c     typedef int(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_get_retry_limit"))) return 0;
\c     return f(d);
\c }
\c int w_get_retry_delay(tuya_device_t *d) {
\c     typedef int(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_get_retry_delay"))) return 0;
\c     return f(d);
\c }
\c
\c bool w_negotiate_session(tuya_device_t *d, const char *k) {
\c     typedef bool(*fn)(tuya_device_t*,const char*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_negotiate_session"))) return false;
\c     return f(d,k);
\c }
\c
\c int w_get_protocol(tuya_device_t *d) {
\c     typedef int(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_get_protocol"))) return 0;
\c     return f(d);
\c }
\c int w_get_session_state(tuya_device_t *d) {
\c     typedef int(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_get_session_state"))) return 0;
\c     return f(d);
\c }
\c int w_get_socket_state(tuya_device_t *d) {
\c     typedef int(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_get_socket_state"))) return 0;
\c     return f(d);
\c }
\c int w_get_last_error(tuya_device_t *d) {
\c     typedef int(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_get_last_error"))) return 0;
\c     return f(d);
\c }
\c
\c void w_set_async_mode(tuya_device_t *d, bool a) {
\c     typedef void(*fn)(tuya_device_t*,bool);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_set_async_mode"))) return;
\c     f(d,a);
\c }
\c
\c /* String-consuming wrappers (strdup + free original) */
\c char *w_status(tuya_device_t *d) {
\c     typedef char*(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_status"))) return NULL;
\c     return consume(f(d));
\c }
\c char *w_turn_on(tuya_device_t *d, int dp) {
\c     typedef char*(*fn)(tuya_device_t*,int);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_turn_on"))) return NULL;
\c     return consume(f(d,dp));
\c }
\c char *w_turn_off(tuya_device_t *d, int dp) {
\c     typedef char*(*fn)(tuya_device_t*,int);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_turn_off"))) return NULL;
\c     return consume(f(d,dp));
\c }
\c char *w_heartbeat(tuya_device_t *d) {
\c     typedef char*(*fn)(tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_heartbeat"))) return NULL;
\c     return consume(f(d));
\c }
\c char *w_set_bool(tuya_device_t *d, int dp, bool v) {
\c     typedef char*(*fn)(tuya_device_t*,int,bool);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_set_value_bool"))) return NULL;
\c     return consume(f(d,dp,v));
\c }
\c char *w_set_int(tuya_device_t *d, int dp, int v) {
\c     typedef char*(*fn)(tuya_device_t*,int,int);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_set_value_int"))) return NULL;
\c     return consume(f(d,dp,v));
\c }
\c char *w_set_string(tuya_device_t *d, int dp, const char *v) {
\c     typedef char*(*fn)(tuya_device_t*,int,const char*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_set_value_string"))) return NULL;
\c     return consume(f(d,dp,v));
\c }
\c char *w_set_float(tuya_device_t *d, int dp, double v) {
\c     typedef char*(*fn)(tuya_device_t*,int,double);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_set_value_float"))) return NULL;
\c     return consume(f(d,dp,v));
\c }
\c
\c void w_set_device22(tuya_device_t *d, const char *j) {
\c     typedef void(*fn)(tuya_device_t*,const char*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_set_device22"))) return;
\c     f(d,j);
\c }
\c bool w_is_device22(tuya_device_t *d) {
\c     typedef bool(*fn)(const tuya_device_t*);
\c     static fn f = NULL;
\c     if (!f && !(f = (fn)dlsym_seatuya("tuya_is_device22"))) return false;
\c     return f(d);
\c }

\c \c end

\ --- Forth wrapper words ---

c-function tuya-version   w_tuya_version         -- s
c-function tuya-create    w_tuya_create       s s s s -- a
c-function tuya-alloc     w_tuya_alloc        s -- a
c-function tuya-destroy   w_tuya_destroy      a -- void

c-function set-creds      w_set_creds          a s s -- void
c-function get-device-id  w_get_devid          a -- s
c-function get-local-key  w_get_key            a -- s
c-function get-ip         w_get_ip             a -- s

c-function tuya-connect        w_connect        a s -- n
c-function tuya-disconnect     w_disconnect     a -- void
c-function tuya-is-connected   w_is_connected   a -- n
c-function tuya-reconnect      w_reconnect      a -- n

c-function set-retry-limit  w_set_retry_limit   a n -- void
c-function set-retry-delay  w_set_retry_delay   a n -- void
c-function get-retry-limit  w_get_retry_limit   a -- n
c-function get-retry-delay  w_get_retry_delay   a -- n

c-function negotiate-session  w_negotiate_session  a s -- n

c-function get-protocol       w_get_protocol       a -- n
c-function get-session-state  w_get_session_state  a -- n
c-function get-socket-state   w_get_socket_state   a -- n
c-function get-last-error     w_get_last_error     a -- n

c-function set-async-mode     w_set_async_mode     a n -- void

c-function tuya-status        w_status        a -- s
c-function tuya-turn-on       w_turn_on       a n -- s
c-function tuya-turn-off      w_turn_off      a n -- s
c-function tuya-heartbeat     w_heartbeat     a -- s
c-function set-value-bool     w_set_bool      a n n -- s
c-function set-value-int      w_set_int       a n n -- s
c-function set-value-string   w_set_string    a n s -- s
c-function set-value-float    w_set_float     a n d -- s

c-function set-device22       w_set_device22  a s -- void
c-function is-device22        w_is_device22   a -- n

end-c-library

\ --- High-level Forth words ---

\ Boolean wrappers
: tuya-is-connected? ( a -- f ) tuya-is-connected 0<> ;
: tuya-reconnect?   ( a -- f ) tuya-reconnect 0<> ;
: negotiate-session? ( a c-addr u -- f ) negotiate-session 0<> ;
: is-device22?      ( a -- f ) is-device22 0<> ;

\ Type-aware set-value dispatcher
: set-value ( a n x -- c-addr u )
  >r >r >r
  r> r> r>   \ roll back to original order
  \ Forth doesn't do runtime type dispatch; use specific word
  ." Use set-value-bool, set-value-int, set-value-string, or set-value-float" cr
;

\ Constants
7   constant cmd-control
10  constant cmd-dp-query
9   constant cmd-heart-beat
8   constant cmd-status
13  constant cmd-control-new
16  constant cmd-dp-query-new

0 constant proto-v31
1 constant proto-v33
2 constant proto-v34
3 constant proto-v35

6668 constant default-port
1024 constant bufsize
5    constant default-retry-limit
100  constant default-retry-delay-ms
