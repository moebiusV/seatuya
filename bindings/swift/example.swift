#!/usr/bin/env swift
import Foundation

let deviceId = ProcessInfo.processInfo.environment["TUYA_DEVICE_ID"] ?? "0123456789abcdef01234567"
let localKey = ProcessInfo.processInfo.environment["TUYA_LOCAL_KEY"] ?? "0123456789abcdef"
let ip       = ProcessInfo.processInfo.environment["TUYA_IP"]        ?? "192.168.1.100"
let ver      = ProcessInfo.processInfo.environment["TUYA_VERSION"]    ?? "3.4"

print("seatuya version:", Seatuya.version())

guard let dev = Seatuya.create(deviceId, ip, localKey, ver) else {
    fputs("ERROR: Could not create device handle\n", stderr)
    exit(1)
}

print("Connected:", Seatuya.isConnected(dev))
print("turn_on:", Seatuya.turnOn(dev) ?? "nil")
print("status:", Seatuya.status(dev) ?? "nil")
print("turn_off:", Seatuya.turnOff(dev) ?? "nil")

Seatuya.destroy(dev)
print("Done.")
