// example.wren -- Demonstrate libseatuya via Wren FFI
//
// Run with a Wren CLI host that has seatuya_wren.c compiled in:
//   wren example.wren
//
// Edit the fallback values below or set the corresponding env vars
// in your shell before running the wren process.
//   export TUYA_DEVICE_ID="0123456789abcdef01234567"
//   export TUYA_IP="192.168.1.100"
//   export TUYA_LOCAL_KEY="0123456789abcdef"
//   export TUYA_VERSION="3.3"

import "seatuya" for Device

var deviceId = "0123456789abcdef01234567"  // or read from env externally
var ip       = "192.168.1.100"
var localKey = "0123456789abcdef"
var ver      = "3.3"

System.print("seatuya version: %(Device.version())")

var dev = Device.create(deviceId, ip, localKey, ver)
if (dev == null) {
  System.print("ERROR: Could not create device handle")
  System.print("  Check IP address, device ID, local key, and protocol version")
  return
}

System.print("Device created")

// Turn on DP 1
var resp = dev.turnOn(1)
if (resp != null) {
  System.print("Turn ON: %(resp)")
} else {
  System.print("Turn ON failed")
}

// Query status
resp = dev.status()
if (resp != null) {
  System.print("Status: %(resp)")
} else {
  System.print("Status query failed")
}

// Turn off DP 1
resp = dev.turnOff(1)
if (resp != null) {
  System.print("Turn OFF: %(resp)")
} else {
  System.print("Turn OFF failed")
}

// Cleanup
dev.destroy()
System.print("Device destroyed.")
