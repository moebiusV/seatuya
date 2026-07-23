\ example.fs -- Demonstrate libseatuya via gforth FFI
\
\ Usage:
\   gforth example.fs -e "bye"
\
\ Set TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP, TUYA_VERSION env vars.

require seatuya.fs

: env-or ( c-addr u c-addr u -- c-addr u )
  >r >r
  getenv dup 0= if
    drop r> r>
  else
    2swap 2drop r> r>
  then
;

s" TUYA_DEVICE_ID" 2env-or s" 0123456789abcdef01234567"
s" TUYA_LOCAL_KEY" 2env-or s" 0123456789abcdef"
s" TUYA_IP"        2env-or s" 192.168.1.100"
s" TUYA_VERSION"   2env-or s" 3.4"

cr ." seatuya version: " tuya-version type cr

tuya-create dup 0= if
  ." ERROR: Could not create device" cr
  bye
then

." Connected: "  dup tuya-is-connected? . cr
." turn_on: "   dup 1 tuya-turn-on type cr
." status: "    dup tuya-status type cr
." turn_off: "  dup 1 tuya-turn-off type cr
." Done." cr

tuya-destroy
bye
