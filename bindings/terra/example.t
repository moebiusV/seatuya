-- example.t — demonstrate libseatuya via Terra

local seatuya = require("seatuya")

local device_id = os.getenv("TUYA_DEVICE_ID") or "0123456789abcdef01234567"
local local_key = os.getenv("TUYA_LOCAL_KEY") or "0123456789abcdef"
local ip        = os.getenv("TUYA_IP")        or "192.168.1.100"
local ver       = os.getenv("TUYA_VERSION")    or "3.4"

print("seatuya version: " .. seatuya.version())

local dev = seatuya.create(device_id, ip, local_key, ver)
if dev == nil then
  io.stderr:write("ERROR: Could not create device handle\n")
  os.exit(1)
end

print("Connected: " .. tostring(seatuya.is_connected(dev)))
print("turn_on: " .. (seatuya.turn_on(dev, 1) or "nil"))
print("status: " .. (seatuya.status(dev) or "nil"))
print("turn_off: " .. (seatuya.turn_off(dev, 1) or "nil"))

seatuya.destroy(dev)
print("Done.")
