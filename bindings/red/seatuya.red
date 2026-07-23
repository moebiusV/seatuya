Red [
    file:    %seatuya.red
    author:  "seatuya"
    purpose: "Red/System FFI bindings for libseatuya"
]

; seatuya.red -- Red FFI bindings for libseatuya
;
; Uses Red's `make routine!` for dynamic FFI through a shared library
; loaded at runtime.  Malloc'd C strings from status, turn_on, etc.
; are auto-converted to Red strings but the original C memory is leaked
; (see README.md for details and workaround).
;
; Usage:
;   seatuya/init
;   dev: seatuya/create "devid" "1.2.3.4" "localkey" "3.4"
;   seatuya/destroy dev

seatuya: context [
    ; Library handle and cached routines
    _lib: none
    _version:        none
    _create:         none
    _alloc:          none
    _destroy:        none
    _set-credentials: none
    _get-device-id:  none
    _get-local-key:  none
    _get-ip:         none
    _connect:        none
    _disconnect:     none
    _is-connected:   none
    _reconnect:      none
    _set-retry-limit: none
    _set-retry-delay: none
    _get-retry-limit: none
    _get-retry-delay: none
    _negotiate-session: none
    _get-protocol:   none
    _get-session-state: none
    _get-socket-state: none
    _get-last-error: none
    _set-async-mode: none
    _is-socket-readable: none
    _is-socket-writable: none
    _set-session-ready: none
    _set-value-bool:none
    _set-value-int: none
    _set-value-string: none
    _set-value-float:none
    _turn-on:        none
    _turn-off:       none
    _status:         none
    _heartbeat:      none
    _free-string:    none
    _set-device22:   none
    _is-device22:    none

    init: function [/local path][
        path: any [
            get-env "SEATUYA_LIB"
            "libseatuya.so"
        ]
        _lib: load-library path
        unless _lib [
            print ["ERROR: Failed to load seatuya library at:" path]
            halt -1
        ]

        _version:   make routine! [[return: [c-string!]]] _lib "tuya_version"
        _create:    make routine! [[c-string! c-string! c-string! c-string! return: [handle!]]] _lib "tuya_create"
        _alloc:     make routine! [[c-string! return: [handle!]]] _lib "tuya_alloc"
        _destroy:   make routine! [[handle!]] _lib "tuya_destroy"

        _set-credentials: make routine! [[handle! c-string! c-string!]] _lib "tuya_set_credentials"
        _get-device-id:   make routine! [[handle! return: [c-string!]]] _lib "tuya_get_device_id"
        _get-local-key:   make routine! [[handle! return: [c-string!]]] _lib "tuya_get_local_key"
        _get-ip:          make routine! [[handle! return: [c-string!]]] _lib "tuya_get_ip"

        _connect:       make routine! [[handle! c-string! return: [logic!]]] _lib "tuya_connect"
        _disconnect:    make routine! [[handle!]] _lib "tuya_disconnect"
        _is-connected:  make routine! [[handle! return: [logic!]]] _lib "tuya_is_connected"
        _reconnect:     make routine! [[handle! return: [logic!]]] _lib "tuya_reconnect"

        _set-retry-limit: make routine! [[handle! int!]] _lib "tuya_set_retry_limit"
        _set-retry-delay: make routine! [[handle! int!]] _lib "tuya_set_retry_delay"
        _get-retry-limit: make routine! [[handle! return: [int!]]] _lib "tuya_get_retry_limit"
        _get-retry-delay: make routine! [[handle! return: [int!]]] _lib "tuya_get_retry_delay"

        _negotiate-session: make routine! [[handle! c-string! return: [logic!]]] _lib "tuya_negotiate_session"

        _get-protocol:      make routine! [[handle! return: [int!]]] _lib "tuya_get_protocol"
        _get-session-state: make routine! [[handle! return: [int!]]] _lib "tuya_get_session_state"
        _get-socket-state:  make routine! [[handle! return: [int!]]] _lib "tuya_get_socket_state"
        _get-last-error:    make routine! [[handle! return: [int!]]] _lib "tuya_get_last_error"

        _set-async-mode:      make routine! [[handle! logic!]] _lib "tuya_set_async_mode"
        _is-socket-readable:  make routine! [[handle! return: [logic!]]] _lib "tuya_is_socket_readable"
        _is-socket-writable:  make routine! [[handle! return: [logic!]]] _lib "tuya_is_socket_writable"
        _set-session-ready:   make routine! [[handle! return: [logic!]]] _lib "tuya_set_session_ready"

        _set-value-bool:   make routine! [[handle! int! logic! return: [c-string!]]] _lib "tuya_set_value_bool"
        _set-value-int:    make routine! [[handle! int! int! return: [c-string!]]] _lib "tuya_set_value_int"
        _set-value-string: make routine! [[handle! int! c-string! return: [c-string!]]] _lib "tuya_set_value_string"
        _set-value-float:  make routine! [[handle! int! float! return: [c-string!]]] _lib "tuya_set_value_float"

        _turn-on:   make routine! [[handle! int! return: [c-string!]]] _lib "tuya_turn_on"
        _turn-off:  make routine! [[handle! int! return: [c-string!]]] _lib "tuya_turn_off"
        _status:    make routine! [[handle! return: [c-string!]]] _lib "tuya_status"
        _heartbeat: make routine! [[handle! return: [c-string!]]] _lib "tuya_heartbeat"

        _free-string:  make routine! [[c-string!]] _lib "tuya_free_string"
        _set-device22: make routine! [[handle! c-string!]] _lib "tuya_set_device22"
        _is-device22:  make routine! [[handle! return: [logic!]]] _lib "tuya_is_device22"
    ]

    ; -- Version
    version: does [_version]

    ; -- Lifecycle
    create: func [
        device-id [string!] address [string!]
        local-key [string!] version  [string!]
    ][
        _create device-id address local-key version
    ]

    alloc: func [version [string!]][
        _alloc version
    ]

    destroy: func [dev [handle!]][
        _destroy dev
    ]

    ; -- Credentials
    set-credentials: func [dev [handle!] device-id [string!] local-key [string!]][
        _set-credentials dev device-id local-key
    ]

    get-device-id: func [dev [handle!]][
        if dev = null [return ""]
        _get-device-id dev
    ]

    get-local-key: func [dev [handle!]][
        if dev = null [return ""]
        _get-local-key dev
    ]

    get-ip: func [dev [handle!]][
        if dev = null [return ""]
        _get-ip dev
    ]

    ; -- Connection
    connect: func [dev [handle!] hostname [string!]][
        _connect dev hostname
    ]

    disconnect: func [dev [handle!]][
        _disconnect dev
    ]

    is-connected: func [dev [handle!]][
        if dev = null [return false]
        _is-connected dev
    ]

    reconnect: func [dev [handle!]][
        _reconnect dev
    ]

    ; -- Retry
    set-retry-limit: func [dev [handle!] limit [integer!]][
        _set-retry-limit dev limit
    ]

    set-retry-delay: func [dev [handle!] ms [integer!]][
        _set-retry-delay dev ms
    ]

    get-retry-limit: func [dev [handle!]][
        _get-retry-limit dev
    ]

    get-retry-delay: func [dev [handle!]][
        _get-retry-delay dev
    ]

    ; -- Session
    negotiate-session: func [dev [handle!] key [string!]][
        _negotiate-session dev key
    ]

    ; -- State queries
    get-protocol: func [dev [handle!]][
        _get-protocol dev
    ]

    get-session-state: func [dev [handle!]][
        _get-session-state dev
    ]

    get-socket-state: func [dev [handle!]][
        _get-socket-state dev
    ]

    get-last-error: func [dev [handle!]][
        _get-last-error dev
    ]

    ; -- Async
    set-async-mode: func [dev [handle!] async [logic!]][
        _set-async-mode dev async
    ]

    is-socket-readable: func [dev [handle!]][
        _is-socket-readable dev
    ]

    is-socket-writable: func [dev [handle!]][
        _is-socket-writable dev
    ]

    set-session-ready: func [dev [handle!]][
        _set-session-ready dev
    ]

    ; -- High-level round-trip (returns auto-converted Red strings)
    ; NOTE: The C strings returned by the library are leaked.  The
    ; data is auto-copied into Red strings but the original C memory
    ; is not freed.  This is negligible in short-lived scripts.

    set-value-bool: func [dev [handle!] dp [integer!] value [logic!]][
        _set-value-bool dev dp value
    ]

    set-value-int: func [dev [handle!] dp [integer!] value [integer!]][
        _set-value-int dev dp value
    ]

    set-value-float: func [dev [handle!] dp [integer!] value [float!]][
        _set-value-float dev dp value
    ]

    set-value-string: func [dev [handle!] dp [integer!] value [string!]][
        _set-value-string dev dp value
    ]

    set-value: func [dev [handle!] dp [integer!] value /local type][
        type: type? value
        case [
            type = logic!     [_set-value-bool   dev dp value]
            type = integer!   [_set-value-int    dev dp value]
            type = float!     [_set-value-float  dev dp value]
            type = string!    [_set-value-string dev dp value]
            true              [_set-value-string dev dp form value]
        ]
    ]

    turn-on: func [dev [handle!] switch-dp [integer!]][
        _turn-on dev switch-dp
    ]

    turn-off: func [dev [handle!] switch-dp [integer!]][
        _turn-off dev switch-dp
    ]

    status: func [dev [handle!]][
        _status dev
    ]

    heartbeat: func [dev [handle!]][
        _heartbeat dev
    ]

    ; -- Memory
    free-string: func [str [string!]][
        _free-string str
    ]

    ; -- device22
    set-device22: func [dev [handle!] null-dps [string!]][
        _set-device22 dev null-dps
    ]

    is-device22: func [dev [handle!]][
        _is-device22 dev
    ]

    ; -- Constants
    udp:                     0
    ap-config:               1
    active:                  2
    bind:                    3
    rename-gw:               4
    rename-device:           5
    unbind:                  6
    control:                 7
    status-cmd:              8
    heart-beat:              9
    dp-query:               10
    query-wifi:             11
    token-bind:             12
    control-new:            13
    enable-wifi:            14
    dp-query-new:           16
    scene-execute:          17
    updatedps:              18
    udp-new:                19
    ap-config-new:          20
    get-local-time:         28
    weather-open:           32
    weather-data:           33
    state-upload-syn:       34
    state-upload-syn-recv:  35
    heart-beat-stop:        37
    stream-trans:           38
    get-wifi-status:        43
    wifi-connect-test:      44
    get-mac:                45
    get-ir-status:          46
    ir-tx-rx-test:          47
    lan-gw-active:         240
    lan-sub-dev-request:   241
    lan-delete-sub-dev:    242
    lan-report-sub-dev:    243
    lan-scene:             244
    lan-publish-cloud-config: 245
    lan-publish-app-config:   246
    lan-export-app-config:    247
    lan-publish-scene-panel:  248
    lan-remove-gw:         249
    lan-check-gw-update:   250
    lan-gw-update:         251
    lan-set-gw-channel:    252

    proto-v31: 0
    proto-v33: 1
    proto-v34: 2
    proto-v35: 3

    default-port: 6668
    bufsize: 1024
    default-retry-limit: 5
    default-retry-delay-ms: 100
]
