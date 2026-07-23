! seatuya.factor -- FFI bindings for libseatuya
!
! Uses Factor's ALIEN FFI library for direct C interop.
! Library path is set via SEATUYA_LIB env var or platform default.
!
! Usage:
!   USE: seatuya
!   dev device-id ip local-key ver tuya-create
!   dev 1 tuya-turn-on consume-cstr .
!   dev tuya-destroy

USING: alien alien.c-types alien.syntax alien.libraries
    system combinators kernel strings locals sequences math
    io io.encodings.utf8 accessors byte-arrays ;
IN: seatuya

! -- Library loading (SEATUYA_LIB env var or platform default) --

"seatuya" {
    { [ "SEATUYA_LIB" os-env ] [ "SEATUYA_LIB" os-env ] }
    { [ os macosx? ] [ "libseatuya.dylib" ] }
    { [ os windows? ] [ "seatuya.dll" ] }
    [ "libseatuya.so" ]
} cond "cdecl" add-library

! -- C function declarations --

LIBRARY: seatuya

! Version & lifecycle
FUNCTION: c-string tuya_version ( )
FUNCTION: void* tuya_create ( c-string device_id c-string address c-string local_key c-string version )
FUNCTION: void* tuya_alloc ( c-string version )
FUNCTION: void tuya_destroy ( void* dev )

! Credentials
FUNCTION: void tuya_set_credentials ( void* dev c-string device_id c-string local_key )
FUNCTION: c-string tuya_get_device_id ( void* dev )
FUNCTION: c-string tuya_get_local_key ( void* dev )
FUNCTION: c-string tuya_get_ip ( void* dev )

! Connection
FUNCTION: int tuya_connect ( void* dev c-string hostname )
FUNCTION: void tuya_disconnect ( void* dev )
FUNCTION: int tuya_is_connected ( void* dev )
FUNCTION: int tuya_reconnect ( void* dev )

! Retry
FUNCTION: void tuya_set_retry_limit ( void* dev int limit )
FUNCTION: void tuya_set_retry_delay ( void* dev int delay_ms )
FUNCTION: int tuya_get_retry_limit ( void* dev )
FUNCTION: int tuya_get_retry_delay ( void* dev )

! Session negotiation
FUNCTION: int tuya_negotiate_session ( void* dev c-string local_key )
FUNCTION: int tuya_negotiate_session_start ( void* dev c-string local_key )
FUNCTION: int tuya_negotiate_session_finalize ( void* dev void* buf int size c-string local_key )

! State queries
FUNCTION: int tuya_get_protocol ( void* dev )
FUNCTION: int tuya_get_session_state ( void* dev )
FUNCTION: int tuya_get_socket_state ( void* dev )
FUNCTION: int tuya_get_last_error ( void* dev )

! Async
FUNCTION: void tuya_set_async_mode ( void* dev int async )
FUNCTION: int tuya_is_socket_readable ( void* dev )
FUNCTION: int tuya_is_socket_writable ( void* dev )
FUNCTION: int tuya_set_session_ready ( void* dev )

! Message building/decoding
FUNCTION: int tuya_build_message ( void* dev void* buf int cmd c-string payload c-string key )
FUNCTION: void* tuya_decode_message ( void* dev void* buf int size c-string key )
FUNCTION: void* tuya_generate_payload ( void* dev int cmd c-string device_id c-string datapoints )

! Raw send/receive
FUNCTION: int tuya_send ( void* dev void* buf int size )
FUNCTION: int tuya_receive ( void* dev void* buf int maxsize int minsize )

! High-level round-trip
FUNCTION: void* tuya_set_value_bool ( void* dev int dp int value )
FUNCTION: void* tuya_set_value_int ( void* dev int dp int value )
FUNCTION: void* tuya_set_value_string ( void* dev int dp c-string value )
FUNCTION: void* tuya_set_value_float ( void* dev int dp double value )

FUNCTION: void* tuya_turn_on ( void* dev int switch_dp )
FUNCTION: void* tuya_turn_off ( void* dev int switch_dp )
FUNCTION: void* tuya_status ( void* dev )
FUNCTION: void* tuya_heartbeat ( void* dev )

! Memory
FUNCTION: void tuya_free_string ( void* str )

! device22
FUNCTION: void tuya_set_device22 ( void* dev c-string null_dps_json )
FUNCTION: int tuya_is_device22 ( void* dev )

! -- Internal helper: consume malloc'd C string (copy then free) --

: consume-cstr ( alien -- str/f )
    dup [
        dup utf8 alien>string
        swap tuya_free_string
    ] when ;

: c-bool>factor ( n -- ? ) 0 = not ;

! -- Wrapper words --

! Lifecycle
: tuya-version ( -- str ) tuya_version ;

: tuya-create ( device-id address local-key ver -- void*/f )
    tuya_create ;

: tuya-alloc ( ver -- void*/f )
    tuya_alloc ;

: tuya-destroy ( dev -- )
    tuya_destroy ;

! Credentials
: tuya-set-credentials ( dev device-id local-key -- )
    tuya_set_credentials ;

: tuya-get-device-id ( dev -- str/f )
    tuya_get_device_id dup [ ] [ drop f ] if ;

: tuya-get-local-key ( dev -- str/f )
    tuya_get_local_key dup [ ] [ drop f ] if ;

: tuya-get-ip ( dev -- str/f )
    tuya_get_ip dup [ ] [ drop f ] if ;

! Connection
: tuya-connect ( dev hostname -- ? )
    tuya_connect c-bool>factor ;

: tuya-disconnect ( dev -- )
    tuya_disconnect ;

: tuya-is-connected ( dev -- ? )
    tuya_is_connected c-bool>factor ;

: tuya-reconnect ( dev -- ? )
    tuya_reconnect c-bool>factor ;

! Retry
: tuya-set-retry-limit ( dev limit -- )
    tuya_set_retry_limit ;

: tuya-set-retry-delay ( dev delay-ms -- )
    tuya_set_retry_delay ;

: tuya-get-retry-limit ( dev -- n )
    tuya_get_retry_limit ;

: tuya-get-retry-delay ( dev -- n )
    tuya_get_retry_delay ;

! Session
: tuya-negotiate-session ( dev local-key -- ? )
    tuya_negotiate_session c-bool>factor ;

: tuya-negotiate-session-start ( dev local-key -- ? )
    tuya_negotiate_session_start c-bool>factor ;

:: tuya-negotiate-session-finalize ( dev buf local-key -- ? )
    dev buf buf length local-key tuya_negotiate_session_finalize c-bool>factor ;

! State
: tuya-get-protocol ( dev -- n )
    tuya_get_protocol ;

: tuya-get-session-state ( dev -- n )
    tuya_get_session_state ;

: tuya-get-socket-state ( dev -- n )
    tuya_get_socket_state ;

: tuya-get-last-error ( dev -- n )
    tuya_get_last_error ;

! Async
: tuya-set-async-mode ( dev ? -- )
    [ 1 ] [ 0 ] if tuya_set_async_mode ;

: tuya-is-socket-readable ( dev -- ? )
    tuya_is_socket_readable c-bool>factor ;

: tuya-is-socket-writable ( dev -- ? )
    tuya_is_socket_writable c-bool>factor ;

: tuya-set-session-ready ( dev -- ? )
    tuya_set_session_ready c-bool>factor ;

! Low-level
:: tuya-build-message ( dev cmd payload key -- byte-array/f )
    1024 <byte-array> :> buf
    dev buf cmd payload key tuya_build_message :> n
    n 0 >= [ buf n head ] [ f ] if ;

:: tuya-decode-message ( dev buf key -- str/f )
    dev buf buf length key tuya_decode_message consume-cstr ;

: tuya-generate-payload ( dev cmd device-id datapoints -- str/f )
    tuya_generate_payload consume-cstr ;

:: tuya-send-frame ( dev buf -- n/f )
    dev buf buf length tuya_send dup 0 < [ drop f ] when ;

:: tuya-receive-frame ( dev maxsize minsize -- byte-array/f )
    maxsize <byte-array> :> buf
    dev buf maxsize minsize tuya_receive :> n
    n 0 >= [ buf n head ] [ f ] if ;

! Type-aware set-value dispatch
:: tuya-set-value ( dev dp val -- str/f )
    dev dp val
    val t [ number? ] [ real? ] bi or [
        val floor val = [ tuya_set_value_int ] [ tuya_set_value_float ] if
    ] [
        val t eq? val f eq? or
        [ 1 0 ? tuya_set_value_bool ]
        [ val >string tuya_set_value_string ] if
    ] if consume-cstr ;

! The two-argument ? 1 0 ? helper for the dispatch above
: ? ( ? true false -- ?/false/true ) spin [ drop ] [ nip ] if ;

! Convenience
: tuya-turn-on ( dev switch-dp -- str/f )
    tuya_turn_on consume-cstr ;

: tuya-turn-off ( dev switch-dp -- str/f )
    tuya_turn_off consume-cstr ;

: tuya-status ( dev -- str/f )
    tuya_status consume-cstr ;

: tuya-heartbeat ( dev -- str/f )
    tuya_heartbeat consume-cstr ;

! device22
: tuya-set-device22 ( dev null-dps-json -- )
    tuya_set_device22 ;

: tuya-is-device22 ( dev -- ? )
    tuya_is_device22 c-bool>factor ;

! -- Command constants --

CONSTANT: commands H{
    { "udp" 0 }
    { "ap-config" 1 }
    { "active" 2 }
    { "bind" 3 }
    { "rename-gw" 4 }
    { "rename-device" 5 }
    { "unbind" 6 }
    { "control" 7 }
    { "status" 8 }
    { "heart-beat" 9 }
    { "dp-query" 10 }
    { "query-wifi" 11 }
    { "token-bind" 12 }
    { "control-new" 13 }
    { "enable-wifi" 14 }
    { "dp-query-new" 16 }
    { "scene-execute" 17 }
    { "updatedps" 18 }
    { "udp-new" 19 }
    { "ap-config-new" 20 }
    { "get-local-time" 28 }
    { "weather-open" 32 }
    { "weather-data" 33 }
    { "state-upload-syn" 34 }
    { "state-upload-syn-recv" 35 }
    { "heart-beat-stop" 37 }
    { "stream-trans" 38 }
    { "get-wifi-status" 43 }
    { "wifi-connect-test" 44 }
    { "get-mac" 45 }
    { "get-ir-status" 46 }
    { "ir-tx-rx-test" 47 }
    { "lan-gw-active" 240 }
    { "lan-sub-dev-request" 241 }
    { "lan-delete-sub-dev" 242 }
    { "lan-report-sub-dev" 243 }
    { "lan-scene" 244 }
    { "lan-publish-cloud-config" 245 }
    { "lan-publish-app-config" 246 }
    { "lan-export-app-config" 247 }
    { "lan-publish-scene-panel" 248 }
    { "lan-remove-gw" 249 }
    { "lan-check-gw-update" 250 }
    { "lan-gw-update" 251 }
    { "lan-set-gw-channel" 252 }
}

CONSTANT: protocols H{ { "v31" 0 } { "v33" 1 } { "v34" 2 } { "v35" 3 } }

CONSTANT: session-states H{
    { "invalid" 0 }
    { "starting" 1 }
    { "finalizing" 2 }
    { "established" 3 }
}

CONSTANT: socket-states H{
    { "no-such-host" 0 }
    { "no-sock-avail" 1 }
    { "failed" 2 }
    { "disconnected" 3 }
    { "connecting" 4 }
    { "connected" 5 }
    { "ready" 6 }
    { "receiving" 7 }
}

CONSTANT: default-port 6668
CONSTANT: bufsize 1024
CONSTANT: default-retry-limit 5
CONSTANT: default-retry-delay-ms 100
