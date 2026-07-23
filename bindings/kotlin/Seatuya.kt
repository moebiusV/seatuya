// Seatuya.kt — Kotlin/JVM JNA bindings for libseatuya
//
// Pure Kotlin binding using Java Native Access (JNA).  Requires:
//   implementation("net.java.dev.jna:jna:5.14.0")
//
// Usage:
//   val dev = Seatuya.create(deviceId, "192.168.1.100", localKey, "3.4")
//   println(Seatuya.turnOn(dev, 1))
//   Seatuya.destroy(dev)

package seatuya

import com.sun.jna.Library
import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.Memory

object Seatuya {
    private val lib: SeatuyaLib = Native.load(
        System.getenv("SEATUYA_LIB") ?: when {
            System.getProperty("os.name").contains("Mac") -> "libseatuya.dylib"
            System.getProperty("os.name").contains("Windows") -> "seatuya.dll"
            else -> "libseatuya.so"
        },
        SeatuyaLib::class.java
    )

    private interface SeatuyaLib : Library {
        fun tuya_version(): String
        fun tuya_create(deviceId: String, address: String, localKey: String, version: String): Pointer?
        fun tuya_alloc(version: String): Pointer?
        fun tuya_destroy(dev: Pointer)
        fun tuya_set_credentials(dev: Pointer, deviceId: String, localKey: String)
        fun tuya_get_device_id(dev: Pointer): String
        fun tuya_get_local_key(dev: Pointer): String
        fun tuya_get_ip(dev: Pointer): String
        fun tuya_connect(dev: Pointer, hostname: String): Boolean
        fun tuya_disconnect(dev: Pointer)
        fun tuya_is_connected(dev: Pointer): Boolean
        fun tuya_reconnect(dev: Pointer): Boolean
        fun tuya_set_retry_limit(dev: Pointer, limit: Int)
        fun tuya_set_retry_delay(dev: Pointer, ms: Int)
        fun tuya_get_retry_limit(dev: Pointer): Int
        fun tuya_get_retry_delay(dev: Pointer): Int
        fun tuya_negotiate_session(dev: Pointer, key: String): Boolean
        fun tuya_negotiate_session_start(dev: Pointer, key: String): Boolean
        fun tuya_negotiate_session_finalize(dev: Pointer, buf: Pointer, size: Int, key: String): Boolean
        fun tuya_get_protocol(dev: Pointer): Int
        fun tuya_get_session_state(dev: Pointer): Int
        fun tuya_get_socket_state(dev: Pointer): Int
        fun tuya_get_last_error(dev: Pointer): Int
        fun tuya_set_async_mode(dev: Pointer, flag: Boolean)
        fun tuya_is_socket_readable(dev: Pointer): Boolean
        fun tuya_is_socket_writable(dev: Pointer): Boolean
        fun tuya_set_session_ready(dev: Pointer): Boolean
        fun tuya_build_message(dev: Pointer, buf: Pointer, cmd: Int, payload: String, key: String): Int
        fun tuya_decode_message(dev: Pointer, buf: Pointer, size: Int, key: String): String?
        fun tuya_generate_payload(dev: Pointer, cmd: Int, deviceId: String, datapoints: String): String?
        fun tuya_send(dev: Pointer, buf: Pointer, size: Int): Int
        fun tuya_receive(dev: Pointer, buf: Pointer, maxsize: Int, minsize: Int): Int
        fun tuya_set_value_bool(dev: Pointer, dp: Int, value: Boolean): String?
        fun tuya_set_value_int(dev: Pointer, dp: Int, value: Int): String?
        fun tuya_set_value_string(dev: Pointer, dp: Int, value: String): String?
        fun tuya_set_value_float(dev: Pointer, dp: Int, value: Double): String?
        fun tuya_turn_on(dev: Pointer, switchDp: Int): String?
        fun tuya_turn_off(dev: Pointer, switchDp: Int): String?
        fun tuya_status(dev: Pointer): String?
        fun tuya_heartbeat(dev: Pointer): String?
        fun tuya_free_string(str: String)
        fun tuya_set_device22(dev: Pointer, nullDpsJson: String)
        fun tuya_is_device22(dev: Pointer): Boolean
    }

    // ── Enums ──
    object Command {
        const val CONTROL = 7; const val DP_QUERY = 10; const val HEART_BEAT = 9
        const val CONTROL_NEW = 13; const val DP_QUERY_NEW = 16; const val STATUS = 8
        const val UDP = 0; const val HEART_BEAT_STOP = 37
    }
    object Protocol { const val V31 = 0; const val V33 = 1; const val V34 = 2; const val V35 = 3 }
    object SessionState { const val INVALID = 0; const val STARTING = 1; const val FINALIZING = 2; const val ESTABLISHED = 3 }
    object SocketState { const val NO_SUCH_HOST = 0; const val NO_SOCK_AVAIL = 1; const val FAILED = 2
        const val DISCONNECTED = 3; const val CONNECTING = 4; const val CONNECTED = 5
        const val READY = 6; const val RECEIVING = 7 }
    const val DEFAULT_PORT = 6668; const val BUFSIZE = 1024
    const val DEFAULT_RETRY_LIMIT = 5; const val DEFAULT_RETRY_DELAY = 100

    // ── Convenience functions ──
    fun version() = lib.tuya_version()
    fun create(deviceId: String, address: String, localKey: String, ver: String): Pointer? =
        lib.tuya_create(deviceId, address, localKey, ver)
    fun alloc(ver: String): Pointer? = lib.tuya_alloc(ver)
    fun destroy(dev: Pointer) = lib.tuya_destroy(dev)
    fun setCredentials(dev: Pointer, id: String, key: String) = lib.tuya_set_credentials(dev, id, key)
    fun getDeviceId(dev: Pointer) = lib.tuya_get_device_id(dev)
    fun getLocalKey(dev: Pointer) = lib.tuya_get_local_key(dev)
    fun getIp(dev: Pointer) = lib.tuya_get_ip(dev)
    fun connect(dev: Pointer, host: String) = lib.tuya_connect(dev, host)
    fun disconnect(dev: Pointer) = lib.tuya_disconnect(dev)
    fun isConnected(dev: Pointer) = lib.tuya_is_connected(dev)
    fun reconnect(dev: Pointer) = lib.tuya_reconnect(dev)
    fun negotiateSession(dev: Pointer, key: String) = lib.tuya_negotiate_session(dev, key)
    fun getProtocol(dev: Pointer) = lib.tuya_get_protocol(dev)
    fun getSessionState(dev: Pointer) = lib.tuya_get_session_state(dev)
    fun getSocketState(dev: Pointer) = lib.tuya_get_socket_state(dev)
    fun getLastError(dev: Pointer) = lib.tuya_get_last_error(dev)
    fun setAsyncMode(dev: Pointer, flag: Boolean) = lib.tuya_set_async_mode(dev, flag)

    fun setValue(dev: Pointer, dp: Int, value: Any?): String? = when (value) {
        is Boolean -> lib.tuya_set_value_bool(dev, dp, value)
        is Int -> lib.tuya_set_value_int(dev, dp, value)
        is Double -> lib.tuya_set_value_float(dev, dp, value)
        else -> lib.tuya_set_value_string(dev, dp, value.toString())
    }

    fun turnOn(dev: Pointer, dp: Int = 1) = lib.tuya_turn_on(dev, dp)
    fun turnOff(dev: Pointer, dp: Int = 1) = lib.tuya_turn_off(dev, dp)
    fun status(dev: Pointer) = lib.tuya_status(dev)
    fun heartbeat(dev: Pointer) = lib.tuya_heartbeat(dev)
    fun setDevice22(dev: Pointer, json: String) = lib.tuya_set_device22(dev, json)
    fun isDevice22(dev: Pointer) = lib.tuya_is_device22(dev)

    // Low-level
    fun buildMessage(dev: Pointer, cmd: Int, payload: String, key: String): ByteArray? {
        val buf = Memory(BUFSIZE.toLong())
        val n = lib.tuya_build_message(dev, buf, cmd, payload, key)
        return if (n > 0) buf.getByteArray(0, n) else null
    }

    fun sendFrame(dev: Pointer, data: ByteArray): Int =
        lib.tuya_send(dev, Memory(data.size.toLong()).also { it.write(0, data, 0, data.size) }, data.size)

    fun receiveFrame(dev: Pointer, maxsize: Int = BUFSIZE, minsize: Int = 0): ByteArray? {
        val buf = Memory(maxsize.toLong())
        val n = lib.tuya_receive(dev, buf, maxsize, minsize)
        return if (n > 0) buf.getByteArray(0, n) else null
    }
}
