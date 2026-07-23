##
## example.nim -- demonstrate seatuya Nim bindings
##
## Usage: nim c -r example.nim
## Environment: DEVICE_ID, LOCAL_KEY, IP, VERSION
##

import os, seatuya

let
  deviceId = getEnv("DEVICE_ID", "0123456789abcdef")
  localKey = getEnv("LOCAL_KEY", "0123456789abcdef")
  ip       = getEnv("IP",        "192.168.1.100")
  version  = getEnv("VERSION",   "3.3")

echo "seatuya version: ", tuyaVersion()
echo "Device ID: ", deviceId
echo "IP: ", ip
echo "Protocol: ", version
echo ""

let dev = tuyaCreate(deviceId, ip, localKey, version)
if dev == nil:
  quit "Failed to create device"

echo "Connected! Getting status..."

var status = tuyaStatus(dev)
if status != nil:
  echo "Status: ", status
else:
  echo "No status response"

echo "Turning on DP 1..."
var result = tuyaTurnOn(dev, 1)
if result != nil:
  echo "Turn-on response: ", result
else:
  echo "Turn-on: no response"

status = tuyaStatus(dev)
if status != nil:
  echo "Status after on: ", status
else:
  echo "No status response"

echo "Turning off DP 1..."
result = tuyaTurnOff(dev, 1)
if result != nil:
  echo "Turn-off response: ", result
else:
  echo "Turn-off: no response"

echo ""
echo "Using type-aware dispatcher:"
result = tuyaSetValue(dev, 1, "bool", true)
if result != nil:
  echo "set-value response: ", result
else:
  echo "set-value: no response"

tuyaDestroy(dev)
echo "Done."
