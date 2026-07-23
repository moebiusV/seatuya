! example.factor -- demonstrate libseatuya via Factor ALIEN FFI
!
! Usage: factor example.factor
! Environment variables (with fallback defaults):
!   TUYA_DEVICE_ID  (default: 0123456789abcdef01234567)
!   TUYA_LOCAL_KEY  (default: 0123456789abcdef)
!   TUYA_IP         (default: 192.168.1.100)
!   TUYA_VERSION    (default: 3.4)

USING: seatuya io io.encodings.utf8 kernel math.parser
    namespaces sequences system ;
IN: example

: getenv-default ( key default -- value )
    os-env dup [ nip ] [ drop ] if ;

"TUYA_DEVICE_ID" "0123456789abcdef01234567" getenv-default :> device-id
"TUYA_LOCAL_KEY" "0123456789abcdef"         getenv-default :> local-key
"TUYA_IP"        "192.168.1.100"            getenv-default :> ip
"TUYA_VERSION"   "3.4"                      getenv-default :> ver

"seatuya version: " write tuya-version print

device-id ip local-key ver tuya-create
dup [
    drop "ERROR: Could not create device handle (check IP and credentials)" print
    1 exit
] unless* :> dev

"Connected: " write dev tuya-is-connected . print

"turn_on: " write dev 1 tuya-turn-on dup [ print ] [ drop "error" print ] if
"status: "  write dev tuya-status dup [ print ] [ drop "error" print ] if
"turn_off: " write dev 1 tuya-turn-off dup [ print ] [ drop "error" print ] if

dev tuya-destroy
"Done." print
