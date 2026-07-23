# seatuya.tcl — Tcl FFI bindings for libseatuya
#
# Pure Tcl binding using the Ffidl extension for dynamic FFI.
# Requires the ffidl package (tclffi on some distributions).
# Alternatively works with critcl for compiled bindings.
#
# Usage:
#   lappend auto_path .
#   package require seatuya
#   set dev [seatuya::create $device_id $ip $local_key "3.4"]
#   puts [seatuya::turn_on $dev 1]
#   puts [seatuya::status $dev]
#   seatuya::destroy $dev

package require Tcl 8.6

namespace eval seatuya {
    variable lib

    # Library discovery
    if {[info exists ::env(SEATUYA_LIB)]} {
        set lib $::env(SEATUYA_LIB)
    } elseif {$::tcl_platform(os) eq "Darwin"} {
        set lib "libseatuya.dylib"
    } elseif {$::tcl_platform(platform) eq "windows"} {
        set lib "seatuya.dll"
    } else {
        set lib "libseatuya.so"
    }

    # Try to load ffidl or critcl
    if {![catch {package require ffidl}]} {
        # Use ffidl for FFI
        ::ffidl::import $lib tuya_version pointer
        ::ffidl::import $lib tuya_create pointer string string string string
        ::ffidl::import $lib tuya_alloc pointer string
        ::ffidl::import $lib tuya_destroy void pointer
        ::ffidl::import $lib tuya_set_credentials void pointer string string
        ::ffidl::import $lib tuya_get_device_id pointer pointer
        ::ffidl::import $lib tuya_get_local_key pointer pointer
        ::ffidl::import $lib tuya_get_ip pointer pointer
        ::ffidl::import $lib tuya_connect int pointer string
        ::ffidl::import $lib tuya_disconnect void pointer
        ::ffidl::import $lib tuya_is_connected int pointer
        ::ffidl::import $lib tuya_reconnect int pointer
        ::ffidl::import $lib tuya_set_retry_limit void pointer int
        ::ffidl::import $lib tuya_set_retry_delay void pointer int
        ::ffidl::import $lib tuya_get_retry_limit int pointer
        ::ffidl::import $lib tuya_get_retry_delay int pointer
        ::ffidl::import $lib tuya_negotiate_session int pointer string
        ::ffidl::import $lib tuya_negotiate_session_start int pointer string
        ::ffidl::import $lib tuya_negotiate_session_finalize int pointer pointer int string
        ::ffidl::import $lib tuya_get_protocol int pointer
        ::ffidl::import $lib tuya_get_session_state int pointer
        ::ffidl::import $lib tuya_get_socket_state int pointer
        ::ffidl::import $lib tuya_get_last_error int pointer
        ::ffidl::import $lib tuya_set_async_mode void pointer int
        ::ffidl::import $lib tuya_is_socket_readable int pointer
        ::ffidl::import $lib tuya_is_socket_writable int pointer
        ::ffidl::import $lib tuya_set_session_ready int pointer
        ::ffidl::import $lib tuya_build_message int pointer pointer int string string
        ::ffidl::import $lib tuya_decode_message pointer pointer int string
        ::ffidl::import $lib tuya_generate_payload pointer pointer int string string
        ::ffidl::import $lib tuya_send int pointer pointer int
        ::ffidl::import $lib tuya_receive int pointer pointer int int
        ::ffidl::import $lib tuya_set_value_bool pointer pointer int int
        ::ffidl::import $lib tuya_set_value_int pointer pointer int int
        ::ffidl::import $lib tuya_set_value_string pointer pointer int string
        ::ffidl::import $lib tuya_set_value_float pointer pointer int double
        ::ffidl::import $lib tuya_turn_on pointer pointer int
        ::ffidl::import $lib tuya_turn_off pointer pointer int
        ::ffidl::import $lib tuya_status pointer pointer
        ::ffidl::import $lib tuya_heartbeat pointer pointer
        ::ffidl::import $lib tuya_free_string void pointer
        ::ffidl::import $lib tuya_set_device22 void pointer string
        ::ffidl::import $lib tuya_is_device22 int pointer
    } elseif {![catch {package require critcl}]} {
        # Fallback: load with raw [load] if compiled as a critcl package
        # (critcl compilation not done here — this is the FFI path)
        error "critcl detected but not configured; install ffidl for pure-Tcl usage"
    } else {
        error "Neither ffidl nor critcl available; install ffidl (tclffi) first"
    }

    # --- Constants ---
    variable CMD_UDP                       0
    variable CMD_AP_CONFIG                 1
    variable CMD_ACTIVE                    2
    variable CMD_BIND                      3
    variable CMD_RENAME_GW                 4
    variable CMD_RENAME_DEVICE             5
    variable CMD_UNBIND                    6
    variable CMD_CONTROL                   7
    variable CMD_STATUS                    8
    variable CMD_HEART_BEAT                9
    variable CMD_DP_QUERY                 10
    variable CMD_QUERY_WIFI               11
    variable CMD_TOKEN_BIND               12
    variable CMD_CONTROL_NEW              13
    variable CMD_ENABLE_WIFI              14
    variable CMD_DP_QUERY_NEW             16
    variable CMD_SCENE_EXECUTE            17
    variable CMD_UPDATEDPS                18
    variable CMD_UDP_NEW                  19
    variable CMD_AP_CONFIG_NEW            20
    variable CMD_GET_LOCAL_TIME           28
    variable CMD_WEATHER_OPEN             32
    variable CMD_WEATHER_DATA             33
    variable CMD_STATE_UPLOAD_SYN         34
    variable CMD_STATE_UPLOAD_SYN_RECV    35
    variable CMD_HEART_BEAT_STOP          37
    variable CMD_STREAM_TRANS             38
    variable CMD_GET_WIFI_STATUS          43
    variable CMD_WIFI_CONNECT_TEST        44
    variable CMD_GET_MAC                  45
    variable CMD_GET_IR_STATUS            46
    variable CMD_IR_TX_RX_TEST            47
    variable CMD_LAN_GW_ACTIVE           240
    variable CMD_LAN_SUB_DEV_REQUEST     241
    variable CMD_LAN_DELETE_SUB_DEV       242
    variable CMD_LAN_REPORT_SUB_DEV       243
    variable CMD_LAN_SCENE                244
    variable CMD_LAN_PUBLISH_CLOUD_CONFIG 245
    variable CMD_LAN_PUBLISH_APP_CONFIG   246
    variable CMD_LAN_EXPORT_APP_CONFIG    247
    variable CMD_LAN_PUBLISH_SCENE_PANEL  248
    variable CMD_LAN_REMOVE_GW            249
    variable CMD_LAN_CHECK_GW_UPDATE      250
    variable CMD_LAN_GW_UPDATE            251
    variable CMD_LAN_SET_GW_CHANNEL       252

    variable PROTO_V31  0
    variable PROTO_V33  1
    variable PROTO_V34  2
    variable PROTO_V35  3

    variable SESSION_INVALID      0
    variable SESSION_STARTING     1
    variable SESSION_FINALIZING   2
    variable SESSION_ESTABLISHED  3

    variable SOCK_NO_SUCH_HOST  0
    variable SOCK_NO_SOCK_AVAIL 1
    variable SOCK_FAILED        2
    variable SOCK_DISCONNECTED  3
    variable SOCK_CONNECTING    4
    variable SOCK_CONNECTED     5
    variable SOCK_READY         6
    variable SOCK_RECEIVING     7

    variable DEFAULT_PORT   6668
    variable BUFSIZE        1024

    # --- Convenience procs ---

    proc version {} {
        return [string range [tuya_version] 0 end]
    }

    proc create {device_id address local_key ver} {
        set ptr [tuya_create $device_id $address $local_key $ver]
        if {$ptr == 0} { return "" }
        return $ptr
    }

    proc alloc {ver} {
        set ptr [tuya_alloc $ver]
        if {$ptr == 0} { return "" }
        return $ptr
    }

    proc destroy {dev} {
        tuya_destroy $dev
    }

    proc set-credentials {dev device_id local_key} {
        tuya_set_credentials $dev $device_id $local_key
    }

    proc get-device-id {dev} {
        return [string range [tuya_get_device_id $dev] 0 end]
    }

    proc get-local-key {dev} {
        return [string range [tuya_get_local_key $dev] 0 end]
    }

    proc get-ip {dev} {
        return [string range [tuya_get_ip $dev] 0 end]
    }

    proc connect {dev hostname} {
        return [expr {[tuya_connect $dev $hostname] != 0}]
    }

    proc disconnect {dev} {
        tuya_disconnect $dev
    }

    proc is-connected {dev} {
        return [expr {[tuya_is_connected $dev] != 0}]
    }

    proc reconnect {dev} {
        return [expr {[tuya_reconnect $dev] != 0}]
    }

    proc set-retry-limit {dev limit} {
        tuya_set_retry_limit $dev $limit
    }

    proc set-retry-delay {dev ms} {
        tuya_set_retry_delay $dev $ms
    }

    proc get-retry-limit {dev} {
        return [tuya_get_retry_limit $dev]
    }

    proc get-retry-delay {dev} {
        return [tuya_get_retry_delay $dev]
    }

    proc negotiate-session {dev key} {
        return [expr {[tuya_negotiate_session $dev $key] != 0}]
    }

    proc get-protocol {dev} {
        return [tuya_get_protocol $dev]
    }

    proc get-session-state {dev} {
        return [tuya_get_session_state $dev]
    }

    proc get-socket-state {dev} {
        return [tuya_get_socket_state $dev]
    }

    proc get-last-error {dev} {
        return [tuya_get_last_error $dev]
    }

    proc set-async-mode {dev flag} {
        tuya_set_async_mode $dev [expr {$flag ? 1 : 0}]
    }

    proc is-socket-readable {dev} {
        return [expr {[tuya_is_socket_readable $dev] != 0}]
    }

    proc is-socket-writable {dev} {
        return [expr {[tuya_is_socket_writable $dev] != 0}]
    }

    proc set-session-ready {dev} {
        return [expr {[tuya_set_session_ready $dev] != 0}]
    }

    # Low-level message functions
    proc build-message {dev cmd payload key} {
        set buf [binary format "c[set ::seatuya::BUFSIZE]" {*}[lrepeat $::seatuya::BUFSIZE 0]]
        set n [tuya_build_message $dev $buf $cmd $payload $key]
        if {$n > 0} {
            return [string range $buf 0 [expr {$n - 1}]]
        }
        return ""
    }

    proc decode-message {dev buf key} {
        set ptr [tuya_decode_message $dev $buf [string length $buf] $key]
        if {$ptr == 0} { return "" }
        set s [string range $ptr 0 end]
        tuya_free_string $ptr
        return $s
    }

    proc generate-payload {dev cmd device_id datapoints} {
        set ptr [tuya_generate_payload $dev $cmd $device_id $datapoints]
        if {$ptr == 0} { return "" }
        set s [string range $ptr 0 end]
        tuya_free_string $ptr
        return $s
    }

    proc send {dev buf} {
        return [tuya_send $dev $buf [string length $buf]]
    }

    proc receive {dev {maxsize 1024} {minsize 0}} {
        set buf [binary format "c$maxsize" {*}[lrepeat $maxsize 0]]
        set n [tuya_receive $dev $buf $maxsize $minsize]
        if {$n > 0} {
            return [string range $buf 0 [expr {$n - 1}]]
        }
        return ""
    }

    # High-level round-trip
    proc set-value {dev dp value} {
        if {[string is boolean -strict $value]} {
            set ptr [tuya_set_value_bool $dev $dp [expr {$value ? 1 : 0}]]
        } elseif {[string is integer -strict $value]} {
            set ptr [tuya_set_value_int $dev $dp $value]
        } elseif {[string is double -strict $value]} {
            set ptr [tuya_set_value_float $dev $dp $value]
        } else {
            set ptr [tuya_set_value_string $dev $dp $value]
        }
        if {$ptr == 0} { return "" }
        set s [string range $ptr 0 end]
        tuya_free_string $ptr
        return $s
    }

    proc turn-on {dev {switch_dp 1}} {
        set ptr [tuya_turn_on $dev $switch_dp]
        if {$ptr == 0} { return "" }
        set s [string range $ptr 0 end]
        tuya_free_string $ptr
        return $s
    }

    proc turn-off {dev {switch_dp 1}} {
        set ptr [tuya_turn_off $dev $switch_dp]
        if {$ptr == 0} { return "" }
        set s [string range $ptr 0 end]
        tuya_free_string $ptr
        return $s
    }

    proc status {dev} {
        set ptr [tuya_status $dev]
        if {$ptr == 0} { return "" }
        set s [string range $ptr 0 end]
        tuya_free_string $ptr
        return $s
    }

    proc heartbeat {dev} {
        set ptr [tuya_heartbeat $dev]
        if {$ptr == 0} { return "" }
        set s [string range $ptr 0 end]
        tuya_free_string $ptr
        return $s
    }

    proc set-device22 {dev null_dps_json} {
        tuya_set_device22 $dev $null_dps_json
    }

    proc is-device22 {dev} {
        return [expr {[tuya_is_device22 $dev] != 0}]
    }

    namespace export -clear *
    namespace ensemble create
}
