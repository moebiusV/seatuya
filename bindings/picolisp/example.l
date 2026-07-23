# example.l -- demonstrate libseatuya via PicoLisp FFI
#
# Usage: pil example.l -DeviceId DEV_ID -LocalKey KEY -IP 192.168.1.x -Version 3.4
#
# Connects to a Tuya device, turns on DP 1, queries status,
# turns off DP 1, and disconnects.

(load "seatuya.l")

(de usage ()
   (prinl "Usage: pil example.l -DeviceId ID -LocalKey KEY -IP IP [-Version VER]")
   (bye 1) )

(off *DeviceId *LocalKey *IP)
(setq *Version "3.4")

# Simple arg parsing
(for (L (cdr (argv)) L (cdr L))
   (case (car L)
      ("-DeviceId" (setq *DeviceId (cadr L)) (pop 'L))
      ("-LocalKey" (setq *LocalKey (cadr L)) (pop 'L))
      ("-IP"       (setq *IP (cadr L))       (pop 'L))
      ("-Version"  (setq *Version (cadr L))   (pop 'L))
      (T (usage)) ) )

(unless (and *DeviceId *LocalKey *IP)
   (usage) )

(prinl "seatuya version: " (seatuya~>version))

# All-in-one: create handle, connect, and negotiate session
(setq Dev (seatuya~>create *DeviceId *IP *LocalKey *Version))
(unless Dev
   (prinl "ERROR: Could not create device handle (check IP and credentials)")
   (bye 1) )

(prinl "Connected: " (seatuya~>is-connected Dev))

# Turn on switch (data point 1)
(prinl "turn_on: " (seatuya~>turn-on Dev 1))

# Query all data points
(prinl "status: " (seatuya~>status Dev))

# Turn off switch
(prinl "turn_off: " (seatuya~>turn-off Dev 1))

(seatuya~>destroy Dev)
(prinl "Done.")
(bye 0)
