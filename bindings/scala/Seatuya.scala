// Seatuya.scala -- Scala/JVM JNA bindings for libseatuya
//
// Pure Scala binding using Java Native Access (JNA).
// Requires: net.java.dev.jna:jna:5.14.0
//
// Usage:
//   import seatuya.Seatuya
//   val dev = Seatuya.create(deviceId, "192.168.1.100", localKey, "3.4")
//   println(Seatuya.turnOn(dev, 1))
//   Seatuya.destroy(dev)

package seatuya

import com.sun.jna.{Library, Native, Pointer, Memory}
import scala.util.Try

object Seatuya {

  // ---- Library loading --------------------------------------------------

  private val libName: String = {
    val env = System.getenv("SEATUYA_LIB")
    if (env != null) env
    else {
      val os = System.getProperty("os.name").toLowerCase
      if (os.contains("mac"))  "libseatuya.dylib"
      else if (os.contains("win")) "seatuya.dll"
      else "libseatuya.so"
    }
  }

  private trait NativeLib extends Library {
    // Version
    def tuya_version(): String

    // Lifecycle
    def tuya_create(deviceId: String, address: String, localKey: String, version: String): Pointer
    def tuya_alloc(version: String): Pointer
    def tuya_destroy(dev: Pointer): Unit

    // Credentials
    def tuya_set_credentials(dev: Pointer, deviceId: String, localKey: String): Unit
    def tuya_get_device_id(dev: Pointer): String
    def tuya_get_local_key(dev: Pointer): String
    def tuya_get_ip(dev: Pointer): String

    // Connection
    def tuya_connect(dev: Pointer, hostname: String): Boolean
    def tuya_disconnect(dev: Pointer): Unit
    def tuya_is_connected(dev: Pointer): Boolean
    def tuya_reconnect(dev: Pointer): Boolean

    // Retry
    def tuya_set_retry_limit(dev: Pointer, limit: Int): Unit
    def tuya_set_retry_delay(dev: Pointer, delayMs: Int): Unit
    def tuya_get_retry_limit(dev: Pointer): Int
    def tuya_get_retry_delay(dev: Pointer): Int

    // Session negotiation
    def tuya_negotiate_session(dev: Pointer, localKey: String): Boolean
    def tuya_negotiate_session_start(dev: Pointer, localKey: String): Boolean
    def tuya_negotiate_session_finalize(dev: Pointer, buf: Pointer, size: Int, localKey: String): Boolean

    // State queries
    def tuya_get_protocol(dev: Pointer): Int
    def tuya_get_session_state(dev: Pointer): Int
    def tuya_get_socket_state(dev: Pointer): Int
    def tuya_get_last_error(dev: Pointer): Int

    // Async mode
    def tuya_set_async_mode(dev: Pointer, asyncFlag: Boolean): Unit
    def tuya_is_socket_readable(dev: Pointer): Boolean
    def tuya_is_socket_writable(dev: Pointer): Boolean
    def tuya_set_session_ready(dev: Pointer): Boolean

    // Message building and decoding
    def tuya_build_message(dev: Pointer, buf: Pointer, cmd: Int, payload: String, key: String): Int
    def tuya_decode_message(dev: Pointer, buf: Pointer, size: Int, key: String): Pointer
    def tuya_generate_payload(dev: Pointer, cmd: Int, deviceId: String, datapoints: String): Pointer

    // Raw send/receive
    def tuya_send(dev: Pointer, buf: Pointer, size: Int): Int
    def tuya_receive(dev: Pointer, buf: Pointer, maxsize: Int, minsize: Int): Int

    // device22 mode
    def tuya_set_device22(dev: Pointer, nullDpsJson: String): Unit
    def tuya_is_device22(dev: Pointer): Boolean

    // High-level round-trip
    def tuya_set_value_bool(dev: Pointer, dp: Int, value: Boolean): Pointer
    def tuya_set_value_int(dev: Pointer, dp: Int, value: Int): Pointer
    def tuya_set_value_string(dev: Pointer, dp: Int, value: String): Pointer
    def tuya_set_value_float(dev: Pointer, dp: Int, value: Double): Pointer
    def tuya_turn_on(dev: Pointer, switchDp: Int): Pointer
    def tuya_turn_off(dev: Pointer, switchDp: Int): Pointer
    def tuya_status(dev: Pointer): Pointer
    def tuya_heartbeat(dev: Pointer): Pointer

    // Memory
    def tuya_free_string(str: Pointer): Unit
  }

  private val lib: NativeLib = Native.load(libName, classOf[NativeLib])

  // ---- Helper: consume a malloc'd C string ------------------------------

  private def consume(ptr: Pointer): String = {
    if (ptr == null) return null
    val s = ptr.getString(0, "UTF-8")
    lib.tuya_free_string(ptr)
    s
  }

  // ---- Constants --------------------------------------------------------

  object Command {
    val UDP = 0; val AP_CONFIG = 1; val ACTIVE = 2; val BIND = 3
    val RENAME_GW = 4; val RENAME_DEVICE = 5; val UNBIND = 6; val CONTROL = 7
    val STATUS = 8; val HEART_BEAT = 9; val DP_QUERY = 10; val QUERY_WIFI = 11
    val TOKEN_BIND = 12; val CONTROL_NEW = 13; val ENABLE_WIFI = 14
    val DP_QUERY_NEW = 16; val SCENE_EXECUTE = 17; val UPDATEDPS = 18
    val UDP_NEW = 19; val AP_CONFIG_NEW = 20; val GET_LOCAL_TIME = 28
    val WEATHER_OPEN = 32; val WEATHER_DATA = 33; val STATE_UPLOAD_SYN = 34
    val STATE_UPLOAD_SYN_RECV = 35; val HEART_BEAT_STOP = 37; val STREAM_TRANS = 38
    val GET_WIFI_STATUS = 43; val WIFI_CONNECT_TEST = 44; val GET_MAC = 45
    val GET_IR_STATUS = 46; val IR_TX_RX_TEST = 47; val LAN_GW_ACTIVE = 240
    val LAN_SUB_DEV_REQUEST = 241; val LAN_DELETE_SUB_DEV = 242
    val LAN_REPORT_SUB_DEV = 243; val LAN_SCENE = 244
    val LAN_PUBLISH_CLOUD_CONFIG = 245; val LAN_PUBLISH_APP_CONFIG = 246
    val LAN_EXPORT_APP_CONFIG = 247; val LAN_PUBLISH_SCENE_PANEL = 248
    val LAN_REMOVE_GW = 249; val LAN_CHECK_GW_UPDATE = 250
    val LAN_GW_UPDATE = 251; val LAN_SET_GW_CHANNEL = 252
  }

  object Protocol {
    val V31 = 0; val V33 = 1; val V34 = 2; val V35 = 3
  }

  object SessionState {
    val INVALID = 0; val STARTING = 1; val FINALIZING = 2; val ESTABLISHED = 3
  }

  object SocketState {
    val NO_SUCH_HOST = 0; val NO_SOCK_AVAIL = 1; val FAILED = 2
    val DISCONNECTED = 3; val CONNECTING = 4; val CONNECTED = 5
    val READY = 6; val RECEIVING = 7
  }

  val DEFAULT_PORT = 6668
  val BUFSIZE = 1024
  val DEFAULT_RETRY_LIMIT = 5
  val DEFAULT_RETRY_DELAY_MS = 100

  // ---- Public API -------------------------------------------------------

  // Version
  def version(): String = lib.tuya_version()

  // Lifecycle
  def create(deviceId: String, address: String, localKey: String, ver: String): Pointer =
    lib.tuya_create(deviceId, address, localKey, ver)

  def alloc(ver: String): Pointer = lib.tuya_alloc(ver)
  def destroy(dev: Pointer): Unit = lib.tuya_destroy(dev)

  // Credentials
  def setCredentials(dev: Pointer, deviceId: String, localKey: String): Unit =
    lib.tuya_set_credentials(dev, deviceId, localKey)

  def getDeviceId(dev: Pointer): String = lib.tuya_get_device_id(dev)
  def getLocalKey(dev: Pointer): String = lib.tuya_get_local_key(dev)
  def getIp(dev: Pointer): String = lib.tuya_get_ip(dev)

  // Connection
  def connect(dev: Pointer, hostname: String): Boolean = lib.tuya_connect(dev, hostname)
  def disconnect(dev: Pointer): Unit = lib.tuya_disconnect(dev)
  def isConnected(dev: Pointer): Boolean = lib.tuya_is_connected(dev)
  def reconnect(dev: Pointer): Boolean = lib.tuya_reconnect(dev)

  // Retry
  def setRetryLimit(dev: Pointer, limit: Int): Unit = lib.tuya_set_retry_limit(dev, limit)
  def setRetryDelay(dev: Pointer, delayMs: Int): Unit = lib.tuya_set_retry_delay(dev, delayMs)
  def getRetryLimit(dev: Pointer): Int = lib.tuya_get_retry_limit(dev)
  def getRetryDelay(dev: Pointer): Int = lib.tuya_get_retry_delay(dev)

  // Session negotiation
  def negotiateSession(dev: Pointer, localKey: String): Boolean =
    lib.tuya_negotiate_session(dev, localKey)

  def negotiateSessionStart(dev: Pointer, localKey: String): Boolean =
    lib.tuya_negotiate_session_start(dev, localKey)

  def negotiateSessionFinalize(dev: Pointer, buf: Pointer, size: Int, localKey: String): Boolean =
    lib.tuya_negotiate_session_finalize(dev, buf, size, localKey)

  // State queries
  def getProtocol(dev: Pointer): Int = lib.tuya_get_protocol(dev)
  def getSessionState(dev: Pointer): Int = lib.tuya_get_session_state(dev)
  def getSocketState(dev: Pointer): Int = lib.tuya_get_socket_state(dev)
  def getLastError(dev: Pointer): Int = lib.tuya_get_last_error(dev)

  // Async mode
  def setAsyncMode(dev: Pointer, flag: Boolean): Unit = lib.tuya_set_async_mode(dev, flag)
  def isSocketReadable(dev: Pointer): Boolean = lib.tuya_is_socket_readable(dev)
  def isSocketWritable(dev: Pointer): Boolean = lib.tuya_is_socket_writable(dev)
  def setSessionReady(dev: Pointer): Boolean = lib.tuya_set_session_ready(dev)

  // Message building and decoding
  def buildMessage(dev: Pointer, cmd: Int, payload: String, key: String): Array[Byte] = {
    val buf = new Memory(BUFSIZE)
    val n = lib.tuya_build_message(dev, buf, cmd, payload, key)
    if (n > 0) buf.getByteArray(0, n) else null
  }

  def decodeMessage(dev: Pointer, buf: Array[Byte], key: String): String = {
    val mem = new Memory(buf.length)
    mem.write(0, buf, 0, buf.length)
    consume(lib.tuya_decode_message(dev, mem, buf.length, key))
  }

  def generatePayload(dev: Pointer, cmd: Int, deviceId: String, datapoints: String): String =
    consume(lib.tuya_generate_payload(dev, cmd, deviceId, datapoints))

  // Raw send/receive
  def sendFrame(dev: Pointer, data: Array[Byte]): Int = {
    val mem = new Memory(data.length)
    mem.write(0, data, 0, data.length)
    lib.tuya_send(dev, mem, data.length)
  }

  def receiveFrame(dev: Pointer, maxsize: Int = BUFSIZE, minsize: Int = 0): Array[Byte] = {
    val buf = new Memory(maxsize)
    val n = lib.tuya_receive(dev, buf, maxsize, minsize)
    if (n > 0) buf.getByteArray(0, n) else null
  }

  // device22 mode
  def setDevice22(dev: Pointer, nullDpsJson: String): Unit =
    lib.tuya_set_device22(dev, nullDpsJson)

  def isDevice22(dev: Pointer): Boolean = lib.tuya_is_device22(dev)

  // High-level round-trip
  def setValueBool(dev: Pointer, dp: Int, value: Boolean): String =
    consume(lib.tuya_set_value_bool(dev, dp, value))

  def setValueInt(dev: Pointer, dp: Int, value: Int): String =
    consume(lib.tuya_set_value_int(dev, dp, value))

  def setValueString(dev: Pointer, dp: Int, value: String): String =
    consume(lib.tuya_set_value_string(dev, dp, value))

  def setValueFloat(dev: Pointer, dp: Int, value: Double): String =
    consume(lib.tuya_set_value_float(dev, dp, value))

  /** Type-aware setValue dispatcher.  Accepts Boolean, Int, Double, and String. */
  def setValue(dev: Pointer, dp: Int, value: Any): String = value match {
    case b: Boolean => setValueBool(dev, dp, b)
    case i: Int     => setValueInt(dev, dp, i)
    case d: Double  => setValueFloat(dev, dp, d)
    case s: String  => setValueString(dev, dp, s)
    case _          => setValueString(dev, dp, value.toString)
  }

  def turnOn(dev: Pointer, switchDp: Int = 1): String =
    consume(lib.tuya_turn_on(dev, switchDp))

  def turnOff(dev: Pointer, switchDp: Int = 1): String =
    consume(lib.tuya_turn_off(dev, switchDp))

  def status(dev: Pointer): String =
    consume(lib.tuya_status(dev))

  def heartbeat(dev: Pointer): String =
    consume(lib.tuya_heartbeat(dev))
}
