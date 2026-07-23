#!/usr/bin/env python3
"""example.py — demonstrate libseatuya via Python ctypes"""

import os
import sys
import seatuya

device_id = os.environ.get("TUYA_DEVICE_ID", "0123456789abcdef01234567")
local_key = os.environ.get("TUYA_LOCAL_KEY", "0123456789abcdef")
ip        = os.environ.get("TUYA_IP",        "192.168.1.100")
ver       = os.environ.get("TUYA_VERSION",    "3.4")

print("seatuya version:", seatuya.version())

dev = seatuya.create(device_id, ip, local_key, ver)
if dev is None:
    print("ERROR: Could not create device handle", file=sys.stderr)
    sys.exit(1)

print(f"Connected: {seatuya.is_connected(dev)}")
print("turn_on:", seatuya.turn_on(dev, 1))
print("status:", seatuya.status(dev))
print("turn_off:", seatuya.turn_off(dev, 1))

seatuya.destroy(dev)
print("Done.")
