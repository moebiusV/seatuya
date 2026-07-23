// seatuya.wren -- Wren FFI bindings for libseatuya
//
// Foreign class whose instances hold a tuya_device_t C pointer.
// The C host must register the methods via seatuyaBindForeignClass
// and seatuyaBindForeignMethod (see seatuya_wren.c).
//
// Usage:
//   import "seatuya" for Device
//   var dev = Device.create("id", "ip", "key", "3.3")
//   if (dev != null) {
//     System.print(dev.turnOn(1))
//     System.print(dev.status())
//     dev.destroy()
//   }

/// Opaque Tuya device handle (foreign class managed by the C host).
foreign class Device {
  /// Return libseatuya version string.
  foreign static version()

  /// Create a device handle, connect, and negotiate session.
  /// Returns a Device instance, or null on failure.
  foreign static create(deviceId, address, localKey, version)

  /// Allocate a device handle without connecting.
  /// Returns a Device instance, or null on failure.
  foreign static alloc(version)

  // ---- Lifecycle ----

  /// Destroy the device handle and free all resources.
  foreign destroy()

  // ---- Credentials ----

  /// Set device ID and local key on an allocated-but-unconnected handle.
  foreign setCredentials(deviceId, localKey)

  /// Get the device ID (internal pointer, do not free).
  foreign getDeviceId()

  /// Get the local key (internal pointer, do not free).
  foreign getLocalKey()

  /// Get the device IP address (internal pointer, do not free).
  foreign getIp()

  // ---- Connection ----

  /// Connect to the device by hostname or IP (port 6668).
  /// Returns true on success.
  foreign connect(hostname)

  /// Disconnect from the device.
  foreign disconnect()

  /// Returns true if the socket is currently connected.
  foreign isConnected()

  /// Reconnect if the connection dropped.
  foreign reconnect()

  // ---- Retry settings ----

  /// Set the maximum number of retry attempts for round-trip ops.
  foreign setRetryLimit(limit)

  /// Set the retry delay in milliseconds.
  foreign setRetryDelay(delayMs)

  /// Get the current retry limit.
  foreign getRetryLimit()

  /// Get the current retry delay in milliseconds.
  foreign getRetryDelay()

  // ---- Session negotiation ----

  /// Perform full session negotiation (blocking). No-op for 3.1/3.3.
  foreign negotiateSession(localKey)

  /// Start session negotiation (async-friendly).
  foreign negotiateSessionStart(localKey)

  /// Finalize session negotiation with device response data.
  /// buf: raw response bytes, localKey: device local key.
  foreign negotiateSessionFinalize(buf, localKey)

  // ---- State queries ----

  /// Get the protocol version enum value (0=V31, 1=V33, 2=V34, 3=V35).
  foreign getProtocol()

  /// Get the session state enum value.
  foreign getSessionState()

  /// Get the socket state enum value.
  foreign getSocketState()

  /// Get the last error code.
  foreign getLastError()

  // ---- Async mode ----

  /// Enable or disable asynchronous socket mode.
  foreign setAsyncMode(async)

  /// Returns true if the socket has data available to read.
  foreign isSocketReadable()

  /// Returns true if the socket is ready for writing.
  foreign isSocketWritable()

  /// Mark the session as ready (async mode, protocol 3.4+).
  foreign setSessionReady()

  // ---- Message building and decoding ----

  /// Build an encrypted Tuya protocol message.
  /// Returns a string with the message bytes, or null on error.
  foreign buildMessage(cmd, payload, key)

  /// Decode a received Tuya protocol message.
  /// Returns the decoded JSON string, or null on error.
  foreign decodeMessage(buf, key)

  /// Generate a JSON payload for a command.
  /// Returns the JSON string, or null on error.
  foreign generatePayload(cmd, deviceId, datapoints)

  // ---- Raw send / receive ----

  /// Send raw bytes to the device. Returns bytes sent, or -1 on error.
  foreign send(buf)

  /// Receive raw bytes from the device.
  /// Returns a string with the received bytes, or null on error/timeout.
  foreign receive(maxsize, minsize)

  // ---- device22 mode ----

  /// Enable device22 fallback mode with null-valued DP map.
  foreign setDevice22(nullDpsJson)

  /// Returns true if device22 mode is enabled.
  foreign isDevice22()

  // ---- High-level round-trip operations ----

  /// Set a boolean DP value. Returns JSON response string, or null.
  foreign setValueBool(dp, value)

  /// Set an integer DP value. Returns JSON response string, or null.
  foreign setValueInt(dp, value)

  /// Set a string DP value. Returns JSON response string, or null.
  foreign setValueString(dp, value)

  /// Set a float DP value. Returns JSON response string, or null.
  foreign setValueFloat(dp, value)

  /// Turn on a switch DP. Returns JSON response string, or null.
  foreign turnOn(switchDp)

  /// Turn off a switch DP. Returns JSON response string, or null.
  foreign turnOff(switchDp)

  /// Query device status. Returns JSON response string, or null.
  foreign status()

  /// Send a heartbeat. Returns JSON response string, or null.
  foreign heartbeat()
}

// ---- Type-aware set_value dispatcher ----

/// Set a DP value, dispatching by the Wren type of value.
/// Booleans  -> setValueBool
/// Integers  -> setValueInt
/// Floats    -> setValueFloat
/// Strings   -> setValueString
var setValue = Fn.new { |dev, dp, value|
  if (value is Bool) {
    return dev.setValueBool(dp, value)
  } else if (value is Num) {
    if (value.isInteger) {
      return dev.setValueInt(dp, value)
    } else {
      return dev.setValueFloat(dp, value)
    }
  } else if (value is String) {
    return dev.setValueString(dp, value)
  }
  Fiber.abort("Unsupported type for setValue")
}

// ---- Constants ----

/// Tuya command type codes.
var Command = {
  "UDP":                       0,
  "AP_CONFIG":                 1,
  "ACTIVE":                    2,
  "BIND":                      3,
  "RENAME_GW":                 4,
  "RENAME_DEVICE":             5,
  "UNBIND":                    6,
  "CONTROL":                   7,
  "STATUS":                    8,
  "HEART_BEAT":                9,
  "DP_QUERY":                 10,
  "QUERY_WIFI":               11,
  "TOKEN_BIND":               12,
  "CONTROL_NEW":              13,
  "ENABLE_WIFI":              14,
  "DP_QUERY_NEW":             16,
  "SCENE_EXECUTE":            17,
  "UPDATEDPS":                18,
  "UDP_NEW":                  19,
  "AP_CONFIG_NEW":            20,
  "GET_LOCAL_TIME":           28,
  "WEATHER_OPEN":             32,
  "WEATHER_DATA":             33,
  "STATE_UPLOAD_SYN":         34,
  "STATE_UPLOAD_SYN_RECV":    35,
  "HEART_BEAT_STOP":          37,
  "STREAM_TRANS":             38,
  "GET_WIFI_STATUS":          43,
  "WIFI_CONNECT_TEST":        44,
  "GET_MAC":                  45,
  "GET_IR_STATUS":            46,
  "IR_TX_RX_TEST":            47,
  "LAN_GW_ACTIVE":           240,
  "LAN_SUB_DEV_REQUEST":     241,
  "LAN_DELETE_SUB_DEV":      242,
  "LAN_REPORT_SUB_DEV":      243,
  "LAN_SCENE":               244,
  "LAN_PUBLISH_CLOUD_CONFIG": 245,
  "LAN_PUBLISH_APP_CONFIG":   246,
  "LAN_EXPORT_APP_CONFIG":    247,
  "LAN_PUBLISH_SCENE_PANEL":  248,
  "LAN_REMOVE_GW":           249,
  "LAN_CHECK_GW_UPDATE":     250,
  "LAN_GW_UPDATE":           251,
  "LAN_SET_GW_CHANNEL":      252,
}

/// Protocol version constants.
var Protocol = {
  "V31": 0,
  "V33": 1,
  "V34": 2,
  "V35": 3,
}

/// Default Tuya device port.
var DefaultPort = 6668

/// Recommended buffer size.
var Bufsize = 1024
