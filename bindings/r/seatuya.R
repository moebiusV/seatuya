#
# seatuya.R -- R bindings for libseatuya (Tuya local device control)
#
# Load the compiled shared library, then use the .Call wrappers
# defined in seatuya_r.c.
#
# Build:
#   R CMD SHLIB -o seatuya_r.so seatuya_r.c -lseatuya
#
# Load (in R):
#   source("seatuya.R")
#   seatuya.init()
#

# ------------------------------------------------------------------
#  Library loading
# ------------------------------------------------------------------

.seatuya.env <- new.env(parent = emptyenv())

#' Load the seatuya shared library.
#'
#' @param lib_path Optional path to the compiled seatuya_r.so.
#'   Defaults to looking for \code{seatuya_r.so} alongside this script,
#'   or the path in the \code{SEATUYA_LIB} environment variable.
#' @export
seatuya.init <- function(lib_path = NULL) {
  if (is.null(lib_path)) {
    lib_path <- Sys.getenv("SEATUYA_LIB",
      unset = file.path(dirname(sys.frame(1)$ofile), "seatuya_r.so"))
  }
  .seatuya.env$lib <- dyn.load(lib_path, local = TRUE)
  invisible(.seatuya.env$lib)
}

# ------------------------------------------------------------------
#  Helper: extract device from arg, check type
# ------------------------------------------------------------------

.assert_device <- function(dev) {
  if (!inherits(dev, "TuyaDevice"))
    stop("'dev' must be a TuyaDevice object", call. = FALSE)
}

# ------------------------------------------------------------------
#  Lifecycle
# ------------------------------------------------------------------

#' Create a device, connect, and negotiate session.
#' @param device_id Tuya device ID (string)
#' @param address IP address or hostname
#' @param local_key Device local key
#' @param version Protocol version (default "3.3")
#' @return A TuyaDevice object, or NULL on failure
#' @export
tuya_create <- function(device_id, address, local_key,
                        version = "3.3") {
  .Call("R_tuya_create", device_id, address, local_key, version)
}

#' Allocate a device handle without connecting.
#' @param version Protocol version string (e.g. "3.3")
#' @export
tuya_alloc <- function(version) {
  .Call("R_tuya_alloc", version)
}

#' Destroy a device handle.
#' @export
tuya_destroy <- function(dev) {
  .assert_device(dev)
  invisible(.Call("R_tuya_destroy", dev))
}

# ------------------------------------------------------------------
#  Credentials
# ------------------------------------------------------------------

#' Set device credentials on an allocated handle.
#' @export
tuya_set_credentials <- function(dev, device_id, local_key) {
  .assert_device(dev)
  invisible(.Call("R_tuya_set_credentials", dev, device_id, local_key))
}

#' Get the device ID.
#' @export
tuya_get_device_id <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_get_device_id", dev)
}

#' Get the local key.
#' @export
tuya_get_local_key <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_get_local_key", dev)
}

#' Get the device IP address.
#' @export
tuya_get_ip <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_get_ip", dev)
}

# ------------------------------------------------------------------
#  Connection
# ------------------------------------------------------------------

#' Connect to a device by hostname or IP.
#' @export
tuya_connect <- function(dev, hostname) {
  .assert_device(dev)
  .Call("R_tuya_connect", dev, hostname)
}

#' Disconnect from the device.
#' @export
tuya_disconnect <- function(dev) {
  .assert_device(dev)
  invisible(.Call("R_tuya_disconnect", dev))
}

#' Returns TRUE if connected.
#' @export
tuya_is_connected <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_is_connected", dev)
}

#' Reconnect if the connection dropped.
#' @export
tuya_reconnect <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_reconnect", dev)
}

# ------------------------------------------------------------------
#  Retry settings
# ------------------------------------------------------------------

#' Set connection retry limit.
#' @export
tuya_set_retry_limit <- function(dev, limit) {
  .assert_device(dev)
  invisible(.Call("R_tuya_set_retry_limit", dev, as.integer(limit)))
}

#' Set connection retry delay in ms.
#' @export
tuya_set_retry_delay <- function(dev, delay_ms) {
  .assert_device(dev)
  invisible(.Call("R_tuya_set_retry_delay", dev, as.integer(delay_ms)))
}

#' Get connection retry limit.
#' @export
tuya_get_retry_limit <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_get_retry_limit", dev)
}

#' Get connection retry delay in ms.
#' @export
tuya_get_retry_delay <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_get_retry_delay", dev)
}

# ------------------------------------------------------------------
#  Session negotiation
# ------------------------------------------------------------------

#' Negotiate session (blocking).
#' @export
tuya_negotiate_session <- function(dev, local_key) {
  .assert_device(dev)
  .Call("R_tuya_negotiate_session", dev, local_key)
}

#' Start session negotiation (async-friendly).
#' @export
tuya_negotiate_session_start <- function(dev, local_key) {
  .assert_device(dev)
  .Call("R_tuya_negotiate_session_start", dev, local_key)
}

#' Finalize session negotiation with device response data.
#' @param buf raw vector containing the device response
#' @export
tuya_negotiate_session_finalize <- function(dev, buf, local_key) {
  .assert_device(dev)
  .Call("R_tuya_negotiate_session_finalize", dev, buf, local_key)
}

# ------------------------------------------------------------------
#  State queries
# ------------------------------------------------------------------

#' Get protocol version enum (integer).
#' @export
tuya_get_protocol <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_get_protocol", dev)
}

#' Get session state enum (integer).
#' @export
tuya_get_session_state <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_get_session_state", dev)
}

#' Get socket state enum (integer).
#' @export
tuya_get_socket_state <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_get_socket_state", dev)
}

#' Get last error code.
#' @export
tuya_get_last_error <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_get_last_error", dev)
}

# ------------------------------------------------------------------
#  Async mode
# ------------------------------------------------------------------

#' Enable or disable async socket mode.
#' @export
tuya_set_async_mode <- function(dev, async) {
  .assert_device(dev)
  invisible(.Call("R_tuya_set_async_mode", dev, async))
}

#' Returns TRUE if the socket has data available to read.
#' @export
tuya_is_socket_readable <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_is_socket_readable", dev)
}

#' Returns TRUE if the socket is ready for writing.
#' @export
tuya_is_socket_writable <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_is_socket_writable", dev)
}

#' Mark the session as ready.
#' @export
tuya_set_session_ready <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_set_session_ready", dev)
}

# ------------------------------------------------------------------
#  Message building / decoding / raw send-receive
# ------------------------------------------------------------------

#' Build an encrypted Tuya protocol message.
#' @param buf raw vector (caller-allocated, recommend 1024+ bytes)
#' @return integer message size, or -1 on error
#' @export
tuya_build_message <- function(dev, buf, cmd, payload, key) {
  .assert_device(dev)
  .Call("R_tuya_build_message", dev, buf, as.integer(cmd), payload, key)
}

#' Decode a received Tuya protocol message.
#' @param buf raw vector of received data
#' @return decoded JSON string, or NULL on error
#' @export
tuya_decode_message <- function(dev, buf, key) {
  .assert_device(dev)
  .Call("R_tuya_decode_message", dev, buf, key)
}

#' Generate a JSON payload for a command.
#' @return JSON string, or NULL on error
#' @export
tuya_generate_payload <- function(dev, cmd, device_id, datapoints) {
  .assert_device(dev)
  .Call("R_tuya_generate_payload", dev, as.integer(cmd), device_id, datapoints)
}

#' Send raw bytes to the device.
#' @return number of bytes sent, or -1 on error
#' @export
tuya_send <- function(dev, buf) {
  .assert_device(dev)
  .Call("R_tuya_send", dev, buf)
}

#' Receive raw bytes from the device.
#' @param maxsize buffer capacity
#' @param minsize minimum response size (0 = default 30)
#' @return raw vector of received bytes, or NULL on error
#' @export
tuya_receive <- function(dev, maxsize, minsize = 0L) {
  .assert_device(dev)
  .Call("R_tuya_receive", dev, as.integer(maxsize), as.integer(minsize))
}

# ------------------------------------------------------------------
#  device22 mode
# ------------------------------------------------------------------

#' Enable device22 mode.
#' @param null_dps_json JSON string of null dps, or NULL to disable
#' @export
tuya_set_device22 <- function(dev, null_dps_json = NULL) {
  .assert_device(dev)
  invisible(.Call("R_tuya_set_device22", dev, null_dps_json))
}

#' Returns TRUE if device22 mode is enabled.
#' @export
tuya_is_device22 <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_is_device22", dev)
}

# ------------------------------------------------------------------
#  High-level round-trip operations
# ------------------------------------------------------------------

#' Set a boolean DP value.
#' @return JSON response string, or NULL on error
#' @export
tuya_set_value_bool <- function(dev, dp, value) {
  .assert_device(dev)
  .Call("R_tuya_set_value_bool", dev, as.integer(dp), value)
}

#' Set an integer DP value.
#' @export
tuya_set_value_int <- function(dev, dp, value) {
  .assert_device(dev)
  .Call("R_tuya_set_value_int", dev, as.integer(dp), as.integer(value))
}

#' Set a string DP value.
#' @export
tuya_set_value_string <- function(dev, dp, value) {
  .assert_device(dev)
  .Call("R_tuya_set_value_string", dev, as.integer(dp), value)
}

#' Set a float DP value.
#' @export
tuya_set_value_float <- function(dev, dp, value) {
  .assert_device(dev)
  .Call("R_tuya_set_value_float", dev, as.integer(dp), value)
}

#' Turn on a switch DP.
#' @export
tuya_turn_on <- function(dev, switch_dp) {
  .assert_device(dev)
  .Call("R_tuya_turn_on", dev, as.integer(switch_dp))
}

#' Turn off a switch DP.
#' @export
tuya_turn_off <- function(dev, switch_dp) {
  .assert_device(dev)
  .Call("R_tuya_turn_off", dev, as.integer(switch_dp))
}

#' Query device status.
#' @export
tuya_status <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_status", dev)
}

#' Send a heartbeat.
#' @export
tuya_heartbeat <- function(dev) {
  .assert_device(dev)
  .Call("R_tuya_heartbeat", dev)
}

# ------------------------------------------------------------------
#  Version
# ------------------------------------------------------------------

#' Get the libseatuya version string.
#' @export
tuya_version <- function() {
  .Call("R_tuya_version")
}

# ------------------------------------------------------------------
#  Type-aware set_value dispatcher
# ------------------------------------------------------------------

#' Set a DP value, dispatching by R type to the correct setter.
#'
#' @param dev a TuyaDevice object
#' @param dp data point ID (integer)
#' @param value the value to set (logical, integer, numeric, or character)
#' @return JSON response string, or NULL on error
#' @export
tuya_set_value <- function(dev, dp, value) {
  if (is.logical(value))
    tuya_set_value_bool(dev, dp, value)
  else if (is.integer(value))
    tuya_set_value_int(dev, dp, value)
  else if (is.numeric(value))
    tuya_set_value_float(dev, dp, value)
  else if (is.character(value))
    tuya_set_value_string(dev, dp, value)
  else
    stop("unsupported value type: ", typeof(value), call. = FALSE)
}

# ------------------------------------------------------------------
#  Constants
# ------------------------------------------------------------------

#' Tuya command type constants
#' @export
TUYA_CMD <- list(
  UDP                   = 0L,
  AP_CONFIG             = 1L,
  ACTIVE                = 2L,
  BIND                  = 3L,
  RENAME_GW             = 4L,
  RENAME_DEVICE         = 5L,
  UNBIND                = 6L,
  CONTROL               = 7L,
  STATUS                = 8L,
  HEART_BEAT            = 9L,
  DP_QUERY              = 10L,
  QUERY_WIFI            = 11L,
  TOKEN_BIND            = 12L,
  CONTROL_NEW           = 13L,
  ENABLE_WIFI           = 14L,
  DP_QUERY_NEW          = 16L,
  SCENE_EXECUTE         = 17L,
  UPDATEDPS             = 18L,
  UDP_NEW               = 19L,
  AP_CONFIG_NEW         = 20L,
  GET_LOCAL_TIME        = 28L,
  WEATHER_OPEN          = 32L,
  WEATHER_DATA          = 33L,
  STATE_UPLOAD_SYN      = 34L,
  STATE_UPLOAD_SYN_RECV = 35L,
  HEART_BEAT_STOP       = 37L,
  STREAM_TRANS          = 38L,
  GET_WIFI_STATUS       = 43L,
  WIFI_CONNECT_TEST     = 44L,
  GET_MAC               = 45L,
  GET_IR_STATUS         = 46L,
  IR_TX_RX_TEST         = 47L,
  LAN_GW_ACTIVE         = 240L,
  LAN_SUB_DEV_REQUEST   = 241L,
  LAN_DELETE_SUB_DEV    = 242L,
  LAN_REPORT_SUB_DEV    = 243L,
  LAN_SCENE             = 244L,
  LAN_PUBLISH_CLOUD_CONFIG = 245L,
  LAN_PUBLISH_APP_CONFIG   = 246L,
  LAN_EXPORT_APP_CONFIG    = 247L,
  LAN_PUBLISH_SCENE_PANEL  = 248L,
  LAN_REMOVE_GW        = 249L,
  LAN_CHECK_GW_UPDATE  = 250L,
  LAN_GW_UPDATE        = 251L,
  LAN_SET_GW_CHANNEL   = 252L
)

#' Protocol version constants
#' @export
TUYA_PROTO <- list(
  V31 = 0L,
  V33 = 1L,
  V34 = 2L,
  V35 = 3L
)

#' Session state constants
#' @export
TUYA_SESSION <- list(
  INVALID     = 0L,
  STARTING    = 1L,
  FINALIZING  = 2L,
  ESTABLISHED = 3L
)

#' Socket state constants
#' @export
TUYA_SOCKET <- list(
  NO_SUCH_HOST  = 0L,
  NO_SOCK_AVAIL = 1L,
  FAILED        = 2L,
  DISCONNECTED  = 3L,
  CONNECTING    = 4L,
  CONNECTED     = 5L,
  READY         = 6L,
  RECEIVING     = 7L
)

#' General constants
#' @export
TUYA_CONST <- list(
  DEFAULT_PORT        = 6668L,
  BUFSIZE             = 1024L,
  DEFAULT_RETRY_LIMIT = 5L,
  DEFAULT_RETRY_DELAY_MS = 100L
)
