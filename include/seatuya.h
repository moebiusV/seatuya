#ifndef TUYA_H
#define TUYA_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * seatuya - C wrapper for the tuyapp C++ Tuya library
 *
 * Provides a pure C API for local Tuya device communication
 * over all supported protocol versions (3.1, 3.3, 3.4, 3.5).
 */


/* ------------------------------------------------------------------ */
/*  Version                                                           */
/* ------------------------------------------------------------------ */

const char *tuya_version(void);


/* ------------------------------------------------------------------ */
/*  Tuya command types                                                */
/* ------------------------------------------------------------------ */

enum tuya_command {
	TUYA_CMD_UDP                       = 0,
	TUYA_CMD_AP_CONFIG                 = 1,
	TUYA_CMD_ACTIVE                    = 2,
	TUYA_CMD_BIND                      = 3,
	TUYA_CMD_RENAME_GW                 = 4,
	TUYA_CMD_RENAME_DEVICE             = 5,
	TUYA_CMD_UNBIND                    = 6,
	TUYA_CMD_CONTROL                   = 7,
	TUYA_CMD_STATUS                    = 8,
	TUYA_CMD_HEART_BEAT                = 9,
	TUYA_CMD_DP_QUERY                  = 10,
	TUYA_CMD_QUERY_WIFI                = 11,
	TUYA_CMD_TOKEN_BIND                = 12,
	TUYA_CMD_CONTROL_NEW               = 13,
	TUYA_CMD_ENABLE_WIFI               = 14,
	TUYA_CMD_DP_QUERY_NEW              = 16,
	TUYA_CMD_SCENE_EXECUTE             = 17,
	TUYA_CMD_UPDATEDPS                 = 18,
	TUYA_CMD_UDP_NEW                   = 19,
	TUYA_CMD_AP_CONFIG_NEW             = 20,
	TUYA_CMD_GET_LOCAL_TIME            = 28,
	TUYA_CMD_WEATHER_OPEN              = 32,
	TUYA_CMD_WEATHER_DATA              = 33,
	TUYA_CMD_STATE_UPLOAD_SYN          = 34,
	TUYA_CMD_STATE_UPLOAD_SYN_RECV     = 35,
	TUYA_CMD_HEART_BEAT_STOP           = 37,
	TUYA_CMD_STREAM_TRANS              = 38,
	TUYA_CMD_GET_WIFI_STATUS           = 43,
	TUYA_CMD_WIFI_CONNECT_TEST         = 44,
	TUYA_CMD_GET_MAC                   = 45,
	TUYA_CMD_GET_IR_STATUS             = 46,
	TUYA_CMD_IR_TX_RX_TEST             = 47,
	TUYA_CMD_LAN_GW_ACTIVE            = 240,
	TUYA_CMD_LAN_SUB_DEV_REQUEST      = 241,
	TUYA_CMD_LAN_DELETE_SUB_DEV        = 242,
	TUYA_CMD_LAN_REPORT_SUB_DEV       = 243,
	TUYA_CMD_LAN_SCENE                 = 244,
	TUYA_CMD_LAN_PUBLISH_CLOUD_CONFIG  = 245,
	TUYA_CMD_LAN_PUBLISH_APP_CONFIG    = 246,
	TUYA_CMD_LAN_EXPORT_APP_CONFIG     = 247,
	TUYA_CMD_LAN_PUBLISH_SCENE_PANEL   = 248,
	TUYA_CMD_LAN_REMOVE_GW             = 249,
	TUYA_CMD_LAN_CHECK_GW_UPDATE       = 250,
	TUYA_CMD_LAN_GW_UPDATE             = 251,
	TUYA_CMD_LAN_SET_GW_CHANNEL        = 252
};


/* ------------------------------------------------------------------ */
/*  Protocol versions                                                 */
/* ------------------------------------------------------------------ */

enum tuya_protocol {
	TUYA_PROTO_V31,
	TUYA_PROTO_V33,
	TUYA_PROTO_V34,
	TUYA_PROTO_V35
};


/* ------------------------------------------------------------------ */
/*  Session state                                                     */
/* ------------------------------------------------------------------ */

enum tuya_session_state {
	TUYA_SESSION_INVALID,
	TUYA_SESSION_STARTING,
	TUYA_SESSION_FINALIZING,
	TUYA_SESSION_ESTABLISHED
};


/* ------------------------------------------------------------------ */
/*  Socket state                                                      */
/* ------------------------------------------------------------------ */

enum tuya_socket_state {
	TUYA_SOCK_NO_SUCH_HOST,
	TUYA_SOCK_NO_SOCK_AVAIL,
	TUYA_SOCK_FAILED,
	TUYA_SOCK_DISCONNECTED,
	TUYA_SOCK_CONNECTING,
	TUYA_SOCK_CONNECTED,
	TUYA_SOCK_READY,
	TUYA_SOCK_RECEIVING
};


/* ------------------------------------------------------------------ */
/*  Opaque device handle                                              */
/* ------------------------------------------------------------------ */

typedef struct tuya_device tuya_device_t;


/* ------------------------------------------------------------------ */
/*  Lifecycle                                                         */
/* ------------------------------------------------------------------ */

/*
 * Recommended buffer size for internal round-trip operations.
 * Used by high-level functions (set_value, status, etc.).
 */

/*
 * Create a device handle, store credentials, connect, and negotiate
 * session -- the full setup in one call.  Equivalent to tinytuya's
 * Device(dev_id, address, local_key, version) constructor.
 * Returns NULL on failure (invalid version, connection error, or
 * session negotiation failure).
 */
tuya_device_t *tuya_create(const char *device_id, const char *address,
                           const char *local_key, const char *version);

/*
 * Allocate a device handle without connecting.
 * version: one of "3.1", "3.3", "3.4", "3.5"
 * Returns NULL on invalid version.
 * For incremental setup: call tuya_set_credentials() and
 * tuya_connect() separately.
 */
tuya_device_t *tuya_alloc(const char *version);

/*
 * Destroy a device handle and free all resources.
 */
void tuya_destroy(tuya_device_t *dev);


/* ------------------------------------------------------------------ */
/*  Credentials                                                       */
/* ------------------------------------------------------------------ */

/*
 * Store device_id and local_key on the handle.
 * Call after create, before high-level operations.
 */
void tuya_set_credentials(tuya_device_t *dev,
                             const char *device_id,
                             const char *local_key);

/*
 * Credential getters (for FFI callers that need them).
 * Return internal pointers -- do not free.
 */
const char *tuya_get_device_id(tuya_device_t *dev);
const char *tuya_get_local_key(tuya_device_t *dev);
const char *tuya_get_ip(tuya_device_t *dev);


/* ------------------------------------------------------------------ */
/*  Connection                                                        */
/* ------------------------------------------------------------------ */

/*
 * Connect to a Tuya device by hostname or IP address (port 6668).
 * Also stores the IP internally for reconnect.
 */
bool tuya_connect(tuya_device_t *dev,
                                   const char *hostname);

/*
 * Disconnect from the device.
 */
void tuya_disconnect(tuya_device_t *dev);

/*
 * Returns true if connected.
 */
bool tuya_is_connected(tuya_device_t *dev);

/*
 * Reconnect if connection dropped.
 * Re-negotiates session for protocol 3.4+.
 * Requires credentials and IP to have been set previously.
 */
bool tuya_reconnect(tuya_device_t *dev);


/* ------------------------------------------------------------------ */
/*  Session negotiation (required for protocol 3.4+)                  */
/* ------------------------------------------------------------------ */

/*
 * Perform full session negotiation (blocking).
 * For protocol 3.1/3.3 this is a no-op that returns success.
 */
bool tuya_negotiate_session(tuya_device_t *dev,
                                             const char *local_key);

/*
 * Start session negotiation (async-friendly).
 */
bool tuya_negotiate_session_start(tuya_device_t *dev,
                                                   const char *local_key);

/*
 * Finalize session negotiation with device response data.
 * buf/size: the raw response received from the device.
 */
bool tuya_negotiate_session_finalize(tuya_device_t *dev,
                                                      unsigned char *buf,
                                                      int size,
                                                      const char *local_key);


/* ------------------------------------------------------------------ */
/*  State queries                                                     */
/* ------------------------------------------------------------------ */

enum tuya_protocol tuya_get_protocol(tuya_device_t *dev);
enum tuya_session_state tuya_get_session_state(tuya_device_t *dev);
enum tuya_socket_state tuya_get_socket_state(tuya_device_t *dev);
int tuya_get_last_error(tuya_device_t *dev);


/* ------------------------------------------------------------------ */
/*  Async mode                                                        */
/* ------------------------------------------------------------------ */

/*
 * Enable or disable asynchronous socket mode.
 * When enabled, receive() returns immediately if no data is available.
 */
void tuya_set_async_mode(tuya_device_t *dev, bool async);

/*
 * Returns true if the socket has data available to read.
 */
bool tuya_is_socket_readable(tuya_device_t *dev);

/*
 * Returns true if the socket is ready for writing.
 */
bool tuya_is_socket_writable(tuya_device_t *dev);

/*
 * Mark the session as ready (call after connection + negotiation in
 * async mode for protocol 3.4+).
 */
bool tuya_set_session_ready(tuya_device_t *dev);


/* ------------------------------------------------------------------ */
/*  Message building and decoding                                     */
/* ------------------------------------------------------------------ */

/*
 * Build an encrypted Tuya protocol message.
 * buf:     output buffer (caller-allocated, recommend 1024+ bytes)
 * cmd:     Tuya command type
 * payload: JSON payload string
 * key:     device local key (encryption key)
 * Returns message size in bytes, or -1 on error.
 */
int tuya_build_message(tuya_device_t *dev,
                                        unsigned char *buf,
                                        enum tuya_command cmd,
                                        const char *payload,
                                        const char *key);

/*
 * Decode a received Tuya protocol message.
 * buf/size: raw received data
 * key:      device local key (encryption key)
 * Returns a newly allocated JSON string, or NULL on error.
 * Caller must free the result with tuya_free_string().
 */
char *tuya_decode_message(tuya_device_t *dev,
                                           unsigned char *buf, int size,
                                           const char *key);

/*
 * Generate a JSON payload for a command.
 * cmd:        Tuya command type
 * device_id:  device identifier
 * datapoints: JSON data points string (e.g. "{\"1\":true}")
 * Returns a newly allocated string, or NULL on error.
 * Caller must free the result with tuya_free_string().
 */
char *tuya_generate_payload(tuya_device_t *dev,
                                             enum tuya_command cmd,
                                             const char *device_id,
                                             const char *datapoints);


/* ------------------------------------------------------------------ */
/*  Raw send/receive                                                  */
/* ------------------------------------------------------------------ */

/*
 * Send raw bytes to the device.
 * Returns number of bytes sent, or -1 on error.
 */
int tuya_send(tuya_device_t *dev, unsigned char *buf, int size);

/*
 * Receive raw bytes from the device.
 * buf:     output buffer (caller-allocated)
 * maxsize: buffer capacity
 * minsize: minimum response size (use 0 for default of 30,
 *          ignored in async mode)
 * Returns number of bytes received, or -1 on error/no data.
 */
int tuya_receive(tuya_device_t *dev, unsigned char *buf,
                    int maxsize, int minsize);


/* ------------------------------------------------------------------ */
/*  High-level round-trip operations                                  */
/* ------------------------------------------------------------------ */

/*
 * Set a single data point value.  Full round-trip: generate payload,
 * build message, send, receive, decode.
 * Returns a malloc'd JSON response string, or NULL on error.
 * Caller must free the result with tuya_free_string().
 * Requires credentials to have been set with tuya_set_credentials().
 */
char *tuya_set_value_bool(tuya_device_t *dev, int dp, bool value);
char *tuya_set_value_int(tuya_device_t *dev, int dp, int value);
char *tuya_set_value_string(tuya_device_t *dev, int dp,
                               const char *value);
char *tuya_set_value_float(tuya_device_t *dev, int dp, double value);

/*
 * Convenience wrappers (tinytuya equivalents).
 * Returns a malloc'd JSON response string, or NULL on error.
 * Caller must free the result with tuya_free_string().
 */
char *tuya_turn_on(tuya_device_t *dev, int switch_dp);
char *tuya_turn_off(tuya_device_t *dev, int switch_dp);
char *tuya_status(tuya_device_t *dev);
char *tuya_heartbeat(tuya_device_t *dev);


/* ------------------------------------------------------------------ */
/*  Memory management                                                 */
/* ------------------------------------------------------------------ */

/*
 * Free a string returned by tuya_decode_message(),
 * tuya_generate_payload(), or any high-level round-trip function.
 */
void tuya_free_string(char *str);


/* ------------------------------------------------------------------ */
/*  Constants                                                         */
/* ------------------------------------------------------------------ */

enum { TUYA_DEFAULT_PORT = 6668 };
enum { TUYA_RECOMMENDED_BUFSIZE = 1024 };


#ifdef __cplusplus
}
#endif

#endif /* TUYA_H */
