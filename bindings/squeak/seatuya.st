"seatuya.st — Squeak Smalltalk FFI bindings for libseatuya

 Squeak's FFI uses the ExternalFunction / ExternalLibrary framework.
 Each C function is declared as a class-side method with the <cdecl:>
 pragma specifying return type, function name, and argument types.

 Usage:
   dev := SeatuyaDevice create: deviceId address: ip localKey: key version: '3.4'.
   Transcript show: (dev turnOn: 1); cr.
   dev destroy.

 Load this file in Squeak via: FileStream fileIn: 'seatuya.st'
"

"══════════════════════════════════════════════════════════════════
  Library loader — wraps dlopen/dlsym
══════════════════════════════════════════════════════════════════"

Object subclass: #SeatuyaLibrary
    instanceVariableNames: ''
    classVariableNames: 'ModulePath'
    poolDictionaries: ''
    category: 'Seatuya-Bindings'

SeatuyaLibrary class >> initialize
    ModulePath := Smalltalk os environment at: 'SEATUYA_LIB' ifAbsent: [
        Smalltalk os isMacOS
            ifTrue: ['libseatuya.dylib']
            ifFalse: [Smalltalk os isWindows
                ifTrue: ['seatuya.dll']
                ifFalse: ['libseatuya.so']]]

SeatuyaLibrary class >> modulePath
    ^ ModulePath

SeatuyaLibrary class >> modulePath: aString
    ModulePath := aString

SeatuyaLibrary initialize.

"══════════════════════════════════════════════════════════════════
  Version
══════════════════════════════════════════════════════════════════"

SeatuyaLibrary class >> tuyaVersion
    <cdecl: String 'tuya_version' () module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

"══════════════════════════════════════════════════════════════════
  Device handle wrapper — opaque tuya_device_t*
══════════════════════════════════════════════════════════════════"

Object subclass: #SeatuyaDevice
    instanceVariableNames: 'handle'
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Seatuya-Bindings'

"── Lifecycle ──"

SeatuyaDevice class >> create: deviceId address: addr localKey: key version: ver
    <cdecl: ExternalAddress 'tuya_create' (String String String String)
        module: SeatuyaLibrary modulePath>
    | ptr |
    ptr := self externalCallFailed.
    ptr isNil ifTrue: [ ^ nil ].
    ^ self new setHandle: ptr

SeatuyaDevice class >> alloc: ver
    <cdecl: ExternalAddress 'tuya_alloc' (String)
        module: SeatuyaLibrary modulePath>
    | ptr |
    ptr := self externalCallFailed.
    ptr isNil ifTrue: [ ^ nil ].
    ^ self new setHandle: ptr

SeatuyaDevice >> setHandle: anExternalAddress
    handle := anExternalAddress

SeatuyaDevice >> handle
    ^ handle

SeatuyaDevice >> destroy
    <cdecl: void 'tuya_destroy' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    self externalCallFailed.
    handle := nil

"── Credentials ──"

SeatuyaDevice >> setCredentials: deviceId localKey: key
    <cdecl: void 'tuya_set_credentials' (ExternalAddress String String)
        module: SeatuyaLibrary modulePath>
    self externalCallFailed

SeatuyaDevice >> deviceId
    <cdecl: String 'tuya_get_device_id' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> localKey
    <cdecl: String 'tuya_get_local_key' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> ip
    <cdecl: String 'tuya_get_ip' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

"── Connection ──"

SeatuyaDevice >> connect: hostname
    <cdecl: SqueakBool 'tuya_connect' (ExternalAddress String)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> disconnect
    <cdecl: void 'tuya_disconnect' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    self externalCallFailed

SeatuyaDevice >> isConnected
    <cdecl: SqueakBool 'tuya_is_connected' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> reconnect
    <cdecl: SqueakBool 'tuya_reconnect' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

"── Retry ──"

SeatuyaDevice >> retryLimit
    <cdecl: int32 'tuya_get_retry_limit' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> retryLimit: limit
    <cdecl: void 'tuya_set_retry_limit' (ExternalAddress int32)
        module: SeatuyaLibrary modulePath>
    self externalCallFailed

SeatuyaDevice >> retryDelay
    <cdecl: int32 'tuya_get_retry_delay' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> retryDelay: ms
    <cdecl: void 'tuya_set_retry_delay' (ExternalAddress int32)
        module: SeatuyaLibrary modulePath>
    self externalCallFailed

"── Session ──"

SeatuyaDevice >> negotiateSession: key
    <cdecl: SqueakBool 'tuya_negotiate_session' (ExternalAddress String)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

"── State ──"

SeatuyaDevice >> protocol
    <cdecl: int32 'tuya_get_protocol' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> sessionState
    <cdecl: int32 'tuya_get_session_state' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> socketState
    <cdecl: int32 'tuya_get_socket_state' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> lastError
    <cdecl: int32 'tuya_get_last_error' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

"── Async ──"

SeatuyaDevice >> asyncMode: aBoolean
    <cdecl: void 'tuya_set_async_mode' (ExternalAddress SqueakBool)
        module: SeatuyaLibrary modulePath>
    self externalCallFailed

SeatuyaDevice >> isSocketReadable
    <cdecl: SqueakBool 'tuya_is_socket_readable' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> isSocketWritable
    <cdecl: SqueakBool 'tuya_is_socket_writable' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> setSessionReady
    <cdecl: SqueakBool 'tuya_set_session_ready' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

"── High-level round-trip ──"

SeatuyaDevice >> turnOn: dp
    <cdecl: String 'tuya_turn_on' (ExternalAddress int32)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> turnOff: dp
    <cdecl: String 'tuya_turn_off' (ExternalAddress int32)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> status
    <cdecl: String 'tuya_status' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> heartbeat
    <cdecl: String 'tuya_heartbeat' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> setValueBool: value forDP: dp
    <cdecl: String 'tuya_set_value_bool' (ExternalAddress int32 SqueakBool)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> setValueInt: value forDP: dp
    <cdecl: String 'tuya_set_value_int' (ExternalAddress int32 int32)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> setValueString: value forDP: dp
    <cdecl: String 'tuya_set_value_string' (ExternalAddress int32 String)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> setValueFloat: value forDP: dp
    <cdecl: String 'tuya_set_value_float' (ExternalAddress int32 double)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

SeatuyaDevice >> setValue: value forDP: dp
    "Type-aware dispatcher: routes to the correct typed C function
     based on the Smalltalk class of the value argument."
    value isString  ifTrue: [ ^ self setValueString: value forDP: dp ].
    value isNumber ifTrue: [
        value isFloat  ifTrue: [ ^ self setValueFloat: value forDP: dp ].
        ^ self setValueInt: value forDP: dp ].
    (value == true or: [ value == false ])
        ifTrue: [ ^ self setValueBool: value forDP: dp ].
    ^ self setValueString: value asString forDP: dp

"── Device22 ──"

SeatuyaDevice >> setDevice22: nullDPSJson
    <cdecl: void 'tuya_set_device22' (ExternalAddress String)
        module: SeatuyaLibrary modulePath>
    self externalCallFailed

SeatuyaDevice >> isDevice22
    <cdecl: SqueakBool 'tuya_is_device22' (ExternalAddress)
        module: SeatuyaLibrary modulePath>
    ^ self externalCallFailed

"═══ Constants ═══"

SeatuyaDevice class >> cmdControl   ^ 7
SeatuyaDevice class >> cmdDPQuery   ^ 10
SeatuyaDevice class >> cmdHeartBeat ^ 9
SeatuyaDevice class >> cmdStatus    ^ 8
SeatuyaDevice class >> cmdControlNew  ^ 13
SeatuyaDevice class >> cmdDPQueryNew  ^ 16
SeatuyaDevice class >> defaultPort  ^ 6668
SeatuyaDevice class >> bufSize      ^ 1024
SeatuyaDevice class >> protoV31 ^ 0
SeatuyaDevice class >> protoV33 ^ 1
SeatuyaDevice class >> protoV34 ^ 2
SeatuyaDevice class >> protoV35 ^ 3
