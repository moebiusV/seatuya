NB. example.ijs -- demonstrate libseatuya via J FFI
NB.
NB. Usage: jconsole example.ijs
NB. Environment variables (with fallback defaults):
NB.   TUYA_DEVICE_ID  (default: 0123456789abcdef01234567)
NB.   TUYA_LOCAL_KEY  (default: 0123456789abcdef)
NB.   TUYA_IP         (default: 192.168.1.100)
NB.   TUYA_VERSION    (default: 3.4)

load 'seatuya'

device_id=: 2!:5 'TUYA_DEVICE_ID'
if. _1 -: device_id do. device_id=: '0123456789abcdef01234567' end.

local_key=: 2!:5 'TUYA_LOCAL_KEY'
if. _1 -: local_key do. local_key=: '0123456789abcdef' end.

ip=: 2!:5 'TUYA_IP'
if. _1 -: ip do. ip=: '192.168.1.100' end.

ver=: 2!:5 'TUYA_VERSION'
if. _1 -: ver do. ver=: '3.4' end.

smoutput 'seatuya version: ', tuya_version ''

dev=: tuya_create device_id;ip;local_key;ver
if. dev = 0 do.
  smoutput 'ERROR: Could not create device handle (check IP and credentials)'
  2!:55 (1)
end.

smoutput 'Connected: ', ": tuya_is_connected dev

smoutput 'turn_on: ', tuya_turn_on dev;1
smoutput 'status: ', tuya_status dev
smoutput 'turn_off: ', tuya_turn_off dev;1

tuya_destroy dev
smoutput 'Done.'
2!:55 (0)
