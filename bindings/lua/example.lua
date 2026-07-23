#!/usr/bin/env luajit
-- example.lua — demonstrate libseatuya via Lua FFI
--
-- Usage: luajit example.lua
-- Set TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP env vars before running.

package.path = "./?.lua;" .. package.path
local seatuya = require("seatuya")

local deviceId = os.getenv("TUYA_DEVICE_ID") or "0123456789abcdef01234567"
local localKey = os.getenv("TUYA_LOCAL_KEY") or "0123456789abcdef"
local ip       = os.getenv("TUYA_IP")        or "192.168.1.100"
local ver      = os.getenv("TUYA_VERSION")    or "3.4"

print("seatuya version:", seatuya.version())

local dev = seatuya.create(deviceId, ip, localKey, ver)
if dev == nil then
  io.stderr:write("ERROR: Could not create device handle (check IP and credentials)\n")
  os.exit(1)
end

print("Connected:", seatuya.is_connected(dev))

print("turn_on:", seatuya.turn_on(dev, 1))
print("status:", seatuya.status(dev))
print("turn_off:", seatuya.turn_off(dev, 1))

seatuya.destroy(dev)
print("Done.")
