#ifndef SEATUYA_H
#define SEATUYA_H

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

const char *seatuya_version(void);


/* ------------------------------------------------------------------ */
/*  Tuya command types                                                */
/* ------------------------------------------------------------------ */

enum seatuya_command {
	SEATUYA_CMD_UDP                       = 0,
	SEATUYA_CMD_AP_CONFIG                 = 1,
	SEATUYA_CMD_ACTIVE                    = 2,
	SEATUYA_CMD_BIND                      = 3,
	SEATUYA_CMD_RENAME_GW                 = 4,
	SEATUYA_CMD_RENAME_DEVICE             = 5,
	SEATUYA_CMD_UNBIND                    = 6,
	SEATUYA_CMD_CONTROL                   = 7,
	SEATUYA_CMD_STATUS                    = 8,
	SEATUYA_CMD_HEART_BEAT                = 9,
	SEATUYA_CMD_DP_QUERY                  = 10,
	SEATUYA_CMD_QUERY_WIFI                = 11,
	SEATUYA_CMD_TOKEN_BIND                = 12,
	SEATUYA_CMD_CONTROL_NEW               = 13,
	SEATUYA_CMD_ENABLE_WIFI               = 14,
	SEATUYA_CMD_DP_QUERY_NEW              = 16,
	SEATUYA_CMD_SCENE_EXECUTE             = 17,
	SEATUYA_CMD_UPDATEDPS                 = 18,
	SEATUYA_CMD_UDP_NEW                   = 19,
	SEATUYA_CMD_AP_CONFIG_NEW             = 20,
	SEATUYA_CMD_GET_LOCAL_TIME            = 28,
	SEATUYA_CMD_WEATHER_OPEN              = 32,
	SEATUYA_CMD_WEATHER_DATA              = 33,
	SEATUYA_CMD_STATE_UPLOAD_SYN          = 34,
	SEATUYA_CMD_STATE_UPLOAD_SYN_RECV     = 35,
	SEATUYA_CMD_HEART_BEAT_STOP           = 37,
	SEATUYA_CMD_STREAM_TRANS              = 38,
	SEATUYA_CMD_GET_WIFI_STATUS           = 43,
	SEATUYA_CMD_WIFI_CONNECT_TEST         = 44,
	SEATUYA_CMD_GET_MAC                   = 45,
	SEATUYA_CMD_GET_IR_STATUS             = 46,
	SEATUYA_CMD_IR_TX_RX_TEST             = 47,
	SEATUYA_CMD_LAN_GW_ACTIVE            = 240,
	SEATUYA_CMD_LAN_SUB_DEV_REQUEST      = 241,
	SEATUYA_CMD_LAN_DELETE_SUB_DEV        = 242,
	SEATUYA_CMD_LAN_REPORT_SUB_DEV       = 243,
	SEATUYA_CMD_LAN_SCENE                 = 244,
	SEATUYA_CMD_LAN_PUBLISH_CLOUD_CONFIG  = 245,
	SEATUYA_CMD_LAN_PUBLISH_APP_CONFIG    = 246,
	SEATUYA_CMD_LAN_EXPORT_APP_CONFIG     = 247,
	SEATUYA_CMD_LAN_PUBLISH_SCENE_PANEL   = 248,
	SEATUYA_CMD_LAN_REMOVE_GW             = 249,
	SEATUYA_CMD_LAN_CHECK_GW_UPDATE       = 250,
	SEATUYA_CMD_LAN_GW_UPDATE             = 251,
	SEATUYA_CMD_LAN_SET_GW_CHANNEL        = 252
};


/* ------------------------------------------------------------------ */
/*  Protocol versions                                                 */
/* ------------------------------------------------------------------ */

enum seatuya_protocol {
	SEATUYA_PROTO_V31,
	SEATUYA_PROTO_V33,
	SEATUYA_PROTO_V34,
	SEATUYA_PROTO_V35
};


/* ------------------------------------------------------------------ */
/*  Session state                                                     */
/* ------------------------------------------------------------------ */

enum seatuya_session_state {
	SEATUYA_SESSION_INVALID,
	SEATUYA_SESSION_STARTING,
	SEATUYA_SESSION_FINALIZING,
	SEATUYA_SESSION_ESTABLISHED
};


/* ------------------------------------------------------------------ */
/*  Socket state                                                      */
/* ------------------------------------------------------------------ */

enum seatuya_socket_state {
	SEATUYA_SOCK_NO_SUCH_HOST,
	SEATUYA_SOCK_NO_SOCK_AVAIL,
	SEATUYA_SOCK_FAILED,
	SEATUYA_SOCK_DISCONNECTED,
	SEATUYA_SOCK_CONNECTING,
	SEATUYA_SOCK_CONNECTED,
	SEATUYA_SOCK_READY,
	SEATUYA_SOCK_RECEIVING
};


/* ------------------------------------------------------------------ */
/*  Opaque device handle                                              */
/* ------------------------------------------------------------------ */

typedef struct seatuya_device seatuya_device_t;


/* ------------------------------------------------------------------ */
/*  Lifecycle                                                         */
/* ------------------------------------------------------------------ */

/*
 * Create a device handle for the given protocol version.
 * version: one of "3.1", "3.3", "3.4", "3.5"
 * Returns NULL on invalid version.
 */
seatuya_device_t *seatuya_create(const char *version);

/*
 * Destroy a device handle and free all resources.
 */
void seatuya_destroy(seatuya_device_t *dev);


/* ------------------------------------------------------------------ */
/*  Connection                                                        */
/* ------------------------------------------------------------------ */

/*
 * Connect to a Tuya device by hostname or IP address (port 6668).
 * Returns 1 on success, 0 on failure.
 */
int seatuya_connect(seatuya_device_t *dev, const char *hostname);

/*
 * Disconnect from the device.
 */
void seatuya_disconnect(seatuya_device_t *dev);

/*
 * Returns 1 if connected, 0 otherwise.
 */
int seatuya_is_connected(seatuya_device_t *dev);


/* ------------------------------------------------------------------ */
/*  Session negotiation (required for protocol 3.4+)                  */
/* ------------------------------------------------------------------ */

/*
 * Perform full session negotiation (blocking).
 * For protocol 3.1/3.3 this is a no-op that returns success.
 * Returns 1 on success, 0 on failure.
 */
int seatuya_negotiate_session(seatuya_device_t *dev, const char *local_key);

/*
 * Start session negotiation (async-friendly).
 * Returns 1 on success, 0 on failure.
 */
int seatuya_negotiate_session_start(seatuya_device_t *dev,
                                    const char *local_key);

/*
 * Finalize session negotiation with device response data.
 * buf/size: the raw response received from the device.
 * Returns 1 on success, 0 on failure.
 */
int seatuya_negotiate_session_finalize(seatuya_device_t *dev,
                                       unsigned char *buf, int size,
                                       const char *local_key);


/* ------------------------------------------------------------------ */
/*  State queries                                                     */
/* ------------------------------------------------------------------ */

enum seatuya_protocol seatuya_get_protocol(seatuya_device_t *dev);
enum seatuya_session_state seatuya_get_session_state(seatuya_device_t *dev);
enum seatuya_socket_state seatuya_get_socket_state(seatuya_device_t *dev);
int seatuya_get_last_error(seatuya_device_t *dev);


/* ------------------------------------------------------------------ */
/*  Async mode                                                        */
/* ------------------------------------------------------------------ */

/*
 * Enable or disable asynchronous socket mode.
 * When enabled, receive() returns immediately if no data is available.
 */
void seatuya_set_async_mode(seatuya_device_t *dev, int async);

/*
 * Returns 1 if the socket has data available to read.
 */
int seatuya_is_socket_readable(seatuya_device_t *dev);

/*
 * Returns 1 if the socket is ready for writing.
 */
int seatuya_is_socket_writable(seatuya_device_t *dev);

/*
 * Mark the session as ready (call after connection + negotiation in
 * async mode for protocol 3.4+).
 * Returns 1 on success, 0 if socket was not in CONNECTED state.
 */
int seatuya_set_session_ready(seatuya_device_t *dev);


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
int seatuya_build_message(seatuya_device_t *dev, unsigned char *buf,
                          enum seatuya_command cmd, const char *payload,
                          const char *key);

/*
 * Decode a received Tuya protocol message.
 * buf/size: raw received data
 * key:      device local key (encryption key)
 * Returns a newly allocated JSON string, or NULL on error.
 * Caller must free the result with seatuya_free_string().
 */
char *seatuya_decode_message(seatuya_device_t *dev, unsigned char *buf,
                             int size, const char *key);

/*
 * Generate a JSON payload for a command.
 * cmd:        Tuya command type
 * device_id:  device identifier
 * datapoints: JSON data points string (e.g. "{\"1\":true}")
 * Returns a newly allocated string, or NULL on error.
 * Caller must free the result with seatuya_free_string().
 */
char *seatuya_generate_payload(seatuya_device_t *dev,
                               enum seatuya_command cmd,
                               const char *device_id,
                               const char *datapoints);


/* ------------------------------------------------------------------ */
/*  Raw send/receive                                                  */
/* ------------------------------------------------------------------ */

/*
 * Send raw bytes to the device.
 * Returns number of bytes sent, or -1 on error.
 */
int seatuya_send(seatuya_device_t *dev, unsigned char *buf, int size);

/*
 * Receive raw bytes from the device.
 * buf:     output buffer (caller-allocated)
 * maxsize: buffer capacity
 * minsize: minimum response size (use 0 for default of 30,
 *          ignored in async mode)
 * Returns number of bytes received, or -1 on error/no data.
 */
int seatuya_receive(seatuya_device_t *dev, unsigned char *buf,
                    int maxsize, int minsize);


/* ------------------------------------------------------------------ */
/*  Memory management                                                 */
/* ------------------------------------------------------------------ */

/*
 * Free a string returned by seatuya_decode_message() or
 * seatuya_generate_payload().
 */
void seatuya_free_string(char *str);


/* ------------------------------------------------------------------ */
/*  Constants                                                         */
/* ------------------------------------------------------------------ */

enum { SEATUYA_DEFAULT_PORT = 6668 };
enum { SEATUYA_RECOMMENDED_BUFSIZE = 1024 };


#ifdef __cplusplus
}
#endif

#endif /* SEATUYA_H */
