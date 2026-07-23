// seatuya.swift — Swift bindings for libseatuya
//
// Pure Swift binding using module maps for C interop.
// Requires a module map or direct dlopen.  Uses OpaquePointer
// for the device handle.
//
// Usage:
//   let dev = Seatuya.create(deviceId, "192.168.1.100", localKey, "3.4")
//   print(Seatuya.turnOn(dev, dp: 1) ?? "failed")
//   Seatuya.destroy(dev)

import Foundation

// Library loading via dlopen
private let libHandle: UnsafeMutableRawPointer = {
    let name = ProcessInfo.processInfo.environment["SEATUYA_LIB"] ?? "libseatuya.so"
    guard let h = dlopen(name, RTLD_NOW) else {
        fatalError("Cannot load libseatuya: \(String(cString: dlerror()))")
    }
    return h
}()

private func sym<T>(_ name: String) -> T {
    let ptr = dlsym(libHandle, name)
    return unsafeBitCast(ptr, to: T.self)
}

// Type aliases
private typealias _VoidFunc       = @convention(c) (OpaquePointer) -> Void
private typealias _BoolFunc       = @convention(c) (OpaquePointer) -> Bool
private typealias _CreateFunc     = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafePointer<CChar>) -> OpaquePointer?
private typealias _ConnectFunc    = @convention(c) (OpaquePointer, UnsafePointer<CChar>) -> Bool
private typealias _SetCredsFunc   = @convention(c) (OpaquePointer, UnsafePointer<CChar>, UnsafePointer<CChar>) -> Void
private typealias _GetStrFunc     = @convention(c) (OpaquePointer) -> UnsafePointer<CChar>?
private typealias _TurnFunc       = @convention(c) (OpaquePointer, Int32) -> UnsafeMutablePointer<CChar>?
private typealias _StatusFunc     = @convention(c) (OpaquePointer) -> UnsafeMutablePointer<CChar>?
private typealias _VersionFunc    = @convention(c) () -> UnsafePointer<CChar>?
private typealias _SetBoolFunc    = @convention(c) (OpaquePointer, Int32, Bool) -> UnsafeMutablePointer<CChar>?
private typealias _SetIntFunc     = @convention(c) (OpaquePointer, Int32, Int32) -> UnsafeMutablePointer<CChar>?
private typealias _SetStrFunc     = @convention(c) (OpaquePointer, Int32, UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
private typealias _SetFloatFunc   = @convention(c) (OpaquePointer, Int32, Double) -> UnsafeMutablePointer<CChar>?

// Function pointers
private let p_version: _VersionFunc = sym("tuya_version")
private let p_create: _CreateFunc = sym("tuya_create")
private let p_destroy: _VoidFunc = sym("tuya_destroy")
private let p_connect: _ConnectFunc = sym("tuya_connect")
private let p_is_connected: _BoolFunc = sym("tuya_is_connected")
private let p_disconnect: _VoidFunc = sym("tuya_disconnect")
private let p_reconnect: _BoolFunc = sym("tuya_reconnect")
private let p_get_device_id: _GetStrFunc = sym("tuya_get_device_id")
private let p_get_local_key: _GetStrFunc = sym("tuya_get_local_key")
private let p_get_ip: _GetStrFunc = sym("tuya_get_ip")
private let p_set_credentials: _SetCredsFunc = sym("tuya_set_credentials")
private let p_turn_on: _TurnFunc = sym("tuya_turn_on")
private let p_turn_off: _TurnFunc = sym("tuya_turn_off")
private let p_status: _StatusFunc = sym("tuya_status")
private let p_heartbeat: _StatusFunc = sym("tuya_heartbeat")
private let p_set_value_bool: _SetBoolFunc = sym("tuya_set_value_bool")
private let p_set_value_int: _SetIntFunc = sym("tuya_set_value_int")
private let p_set_value_string: _SetStrFunc = sym("tuya_set_value_string")
private let p_set_value_float: _SetFloatFunc = sym("tuya_set_value_float")
private let p_free_string: @convention(c) (UnsafeMutablePointer<CChar>?) -> Void = sym("tuya_free_string")
private let p_get_protocol: @convention(c) (OpaquePointer) -> Int32 = sym("tuya_get_protocol")
private let p_get_last_error: @convention(c) (OpaquePointer) -> Int32 = sym("tuya_get_last_error")
private let p_set_device22: @convention(c) (OpaquePointer, UnsafePointer<CChar>?) -> Void = sym("tuya_set_device22")

// Constants
public enum Command { public static let control = 7, dpQuery = 10, heartBeat = 9, status = 8, controlNew = 13, dpQueryNew = 16 }
public enum Protocol_ { public static let v31 = 0, v33 = 1, v34 = 2, v35 = 3 }
public let DEFAULT_PORT = 6668, BUFSIZE = 1024

// Convenience API
public enum Seatuya {
    public static func version() -> String { String(cString: p_version()!) }

    public static func create(_ deviceId: String, _ address: String, _ localKey: String, _ ver: String) -> OpaquePointer? {
        return p_create(deviceId, address, localKey, ver)
    }

    public static func destroy(_ dev: OpaquePointer) { p_destroy(dev) }
    public static func connect(_ dev: OpaquePointer, _ host: String) -> Bool { p_connect(dev, host) }
    public static func disconnect(_ dev: OpaquePointer) { p_disconnect(dev) }
    public static func isConnected(_ dev: OpaquePointer) -> Bool { p_is_connected(dev) }
    public static func reconnect(_ dev: OpaquePointer) -> Bool { p_reconnect(dev) }
    public static func setCredentials(_ dev: OpaquePointer, _ id: String, _ key: String) { p_set_credentials(dev, id, key) }
    public static func getDeviceId(_ dev: OpaquePointer) -> String? { p_get_device_id(dev).map { String(cString: $0) } }
    public static func getLocalKey(_ dev: OpaquePointer) -> String? { p_get_local_key(dev).map { String(cString: $0) } }
    public static func getIp(_ dev: OpaquePointer) -> String? { p_get_ip(dev).map { String(cString: $0) } }
    public static func getProtocol(_ dev: OpaquePointer) -> Int32 { p_get_protocol(dev) }
    public static func getLastError(_ dev: OpaquePointer) -> Int32 { p_get_last_error(dev) }
    public static func setDevice22(_ dev: OpaquePointer, _ json: String?) { p_set_device22(dev, json) }

    private static func consume(_ ptr: UnsafeMutablePointer<CChar>?) -> String? {
        guard let p = ptr else { return nil }
        defer { p_free_string(p) }
        return String(cString: p)
    }

    public static func setValue(_ dev: OpaquePointer, dp: Int32, value: Any) -> String? {
        switch value {
        case let b as Bool:   return consume(p_set_value_bool(dev, dp, b))
        case let i as Int32:  return consume(p_set_value_int(dev, dp, i))
        case let d as Double: return consume(p_set_value_float(dev, dp, d))
        default:              return consume(p_set_value_string(dev, dp, String(describing: value)))
        }
    }

    public static func turnOn(_ dev: OpaquePointer, dp: Int32 = 1) -> String? { consume(p_turn_on(dev, dp)) }
    public static func turnOff(_ dev: OpaquePointer, dp: Int32 = 1) -> String? { consume(p_turn_off(dev, dp)) }
    public static func status(_ dev: OpaquePointer) -> String? { consume(p_status(dev)) }
    public static func heartbeat(_ dev: OpaquePointer) -> String? { consume(p_heartbeat(dev)) }
}
