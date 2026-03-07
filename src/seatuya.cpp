/*
 * seatuya - C wrapper for the tuyapp C++ Tuya library
 *
 * Copyright (c) 2026, David Walther <david@clearbrookdistillery.com>
 * BSD-2-Clause — see COPYING for details.
 */

#include "seatuya.h"
#include "tuyaAPI.hpp"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unistd.h>

struct tuya_device {
	tuyaAPI *api;
	char *device_id;
	char *local_key;
	char *ip;
	unsigned char buf[TUYA_RECOMMENDED_BUFSIZE];
};


/* ------------------------------------------------------------------ */
/*  Version                                                           */
/* ------------------------------------------------------------------ */

extern "C" const char *
tuya_version(void)
{
	return "0.2.0";
}


/* ------------------------------------------------------------------ */
/*  Lifecycle                                                         */
/* ------------------------------------------------------------------ */

extern "C" tuya_device_t *
tuya_create(const char *version)
{
	if (!version)
		return NULL;

	tuyaAPI *api = tuyaAPI::create(std::string(version));
	if (!api)
		return NULL;

	tuya_device_t *dev = (tuya_device_t *)calloc(1, sizeof(*dev));
	if (!dev) {
		delete api;
		return NULL;
	}
	dev->api = api;
	return dev;
}

extern "C" void
tuya_destroy(tuya_device_t *dev)
{
	if (!dev)
		return;
	delete dev->api;
	free(dev->device_id);
	free(dev->local_key);
	free(dev->ip);
	free(dev);
}


/* ------------------------------------------------------------------ */
/*  Credentials                                                       */
/* ------------------------------------------------------------------ */

static char *
dup_str(const char *s)
{
	if (!s)
		return NULL;
	size_t len = strlen(s);
	char *out = (char *)malloc(len + 1);
	if (out)
		memcpy(out, s, len + 1);
	return out;
}

extern "C" void
tuya_set_credentials(tuya_device_t *dev, const char *device_id,
                        const char *local_key)
{
	if (!dev)
		return;
	free(dev->device_id);
	free(dev->local_key);
	dev->device_id = dup_str(device_id);
	dev->local_key = dup_str(local_key);
}

extern "C" const char *
tuya_get_device_id(tuya_device_t *dev)
{
	return dev ? dev->device_id : NULL;
}

extern "C" const char *
tuya_get_local_key(tuya_device_t *dev)
{
	return dev ? dev->local_key : NULL;
}

extern "C" const char *
tuya_get_ip(tuya_device_t *dev)
{
	return dev ? dev->ip : NULL;
}


/* ------------------------------------------------------------------ */
/*  Connection                                                        */
/* ------------------------------------------------------------------ */

extern "C" bool
tuya_connect(tuya_device_t *dev, const char *hostname)
{
	if (!dev || !hostname)
		return false;
	free(dev->ip);
	dev->ip = dup_str(hostname);
	return dev->api->ConnectToDevice(std::string(hostname));
}

extern "C" bool
tuya_reconnect(tuya_device_t *dev)
{
	if (!dev || !dev->ip || !dev->local_key)
		return false;
	if (dev->api->isConnected())
		return true;
	if (!dev->api->ConnectToDevice(std::string(dev->ip)))
		return false;
	switch (dev->api->getProtocol()) {
	case tuyaAPI::Protocol::v34:
	case tuyaAPI::Protocol::v35:
		return dev->api->NegotiateSession(std::string(dev->local_key));
	default:
		return true;
	}
}

extern "C" void
tuya_disconnect(tuya_device_t *dev)
{
	if (dev)
		dev->api->disconnect();
}

extern "C" bool
tuya_is_connected(tuya_device_t *dev)
{
	if (!dev)
		return false;
	return dev->api->isConnected();
}


/* ------------------------------------------------------------------ */
/*  Session negotiation                                               */
/* ------------------------------------------------------------------ */

extern "C" bool
tuya_negotiate_session(tuya_device_t *dev, const char *local_key)
{
	if (!dev || !local_key)
		return false;
	return dev->api->NegotiateSession(std::string(local_key));
}

extern "C" bool
tuya_negotiate_session_start(tuya_device_t *dev, const char *local_key)
{
	if (!dev || !local_key)
		return false;
	return dev->api->NegotiateSessionStart(std::string(local_key));
}

extern "C" bool
tuya_negotiate_session_finalize(tuya_device_t *dev,
                                   unsigned char *buf, int size,
                                   const char *local_key)
{
	if (!dev || !buf || !local_key)
		return false;
	return dev->api->NegotiateSessionFinalize(buf, size,
	           std::string(local_key));
}


/* ------------------------------------------------------------------ */
/*  State queries                                                     */
/* ------------------------------------------------------------------ */

extern "C" enum tuya_protocol
tuya_get_protocol(tuya_device_t *dev)
{
	if (!dev)
		return TUYA_PROTO_V33;

	switch (dev->api->getProtocol()) {
	case tuyaAPI::Protocol::v31: return TUYA_PROTO_V31;
	case tuyaAPI::Protocol::v33: return TUYA_PROTO_V33;
	case tuyaAPI::Protocol::v34: return TUYA_PROTO_V34;
	case tuyaAPI::Protocol::v35: return TUYA_PROTO_V35;
	}
	return TUYA_PROTO_V33;
}

extern "C" enum tuya_session_state
tuya_get_session_state(tuya_device_t *dev)
{
	if (!dev)
		return TUYA_SESSION_INVALID;

	switch (dev->api->getSessionState()) {
	case Tuya::Session::INVALID:      return TUYA_SESSION_INVALID;
	case Tuya::Session::STARTING:     return TUYA_SESSION_STARTING;
	case Tuya::Session::FINALIZING:   return TUYA_SESSION_FINALIZING;
	case Tuya::Session::ESTABLISHED:  return TUYA_SESSION_ESTABLISHED;
	}
	return TUYA_SESSION_INVALID;
}

extern "C" enum tuya_socket_state
tuya_get_socket_state(tuya_device_t *dev)
{
	if (!dev)
		return TUYA_SOCK_DISCONNECTED;

	switch (dev->api->getSocketState()) {
	case Tuya::TCP::Socket::NO_SUCH_HOST:  return TUYA_SOCK_NO_SUCH_HOST;
	case Tuya::TCP::Socket::NO_SOCK_AVAIL: return TUYA_SOCK_NO_SOCK_AVAIL;
	case Tuya::TCP::Socket::FAILED:        return TUYA_SOCK_FAILED;
	case Tuya::TCP::Socket::DISCONNECTED:  return TUYA_SOCK_DISCONNECTED;
	case Tuya::TCP::Socket::CONNECTING:    return TUYA_SOCK_CONNECTING;
	case Tuya::TCP::Socket::CONNECTED:     return TUYA_SOCK_CONNECTED;
	case Tuya::TCP::Socket::READY:         return TUYA_SOCK_READY;
	case Tuya::TCP::Socket::RECEIVING:     return TUYA_SOCK_RECEIVING;
	}
	return TUYA_SOCK_DISCONNECTED;
}

extern "C" int
tuya_get_last_error(tuya_device_t *dev)
{
	if (!dev)
		return -1;
	return dev->api->getlasterror();
}


/* ------------------------------------------------------------------ */
/*  Async mode                                                        */
/* ------------------------------------------------------------------ */

extern "C" void
tuya_set_async_mode(tuya_device_t *dev, bool async)
{
	if (dev)
		dev->api->setAsyncMode(async);
}

extern "C" bool
tuya_is_socket_readable(tuya_device_t *dev)
{
	if (!dev)
		return false;
	return dev->api->isSocketReadable();
}

extern "C" bool
tuya_is_socket_writable(tuya_device_t *dev)
{
	if (!dev)
		return false;
	return dev->api->isSocketWritable();
}

extern "C" bool
tuya_set_session_ready(tuya_device_t *dev)
{
	if (!dev)
		return false;
	return dev->api->setSessionReady();
}


/* ------------------------------------------------------------------ */
/*  Message building and decoding                                     */
/* ------------------------------------------------------------------ */

extern "C" int
tuya_build_message(tuya_device_t *dev, unsigned char *buf,
                      enum tuya_command cmd, const char *payload,
                      const char *key)
{
	if (!dev || !buf || !payload || !key)
		return -1;
	return dev->api->BuildTuyaMessage(buf, (uint8_t)cmd,
	           std::string(payload), std::string(key));
}

extern "C" char *
tuya_decode_message(tuya_device_t *dev, unsigned char *buf,
                       int size, const char *key)
{
	if (!dev || !buf || !key)
		return NULL;

	std::string result = dev->api->DecodeTuyaMessage(buf, size,
	                         std::string(key));
	if (result.empty())
		return NULL;

	char *out = (char *)malloc(result.size() + 1);
	if (!out)
		return NULL;
	memcpy(out, result.c_str(), result.size() + 1);
	return out;
}

extern "C" char *
tuya_generate_payload(tuya_device_t *dev,
                         enum tuya_command cmd,
                         const char *device_id,
                         const char *datapoints)
{
	if (!dev || !device_id)
		return NULL;

	std::string dp = datapoints ? std::string(datapoints) : std::string();
	std::string result = dev->api->GeneratePayload((uint8_t)cmd,
	                         std::string(device_id), dp);
	if (result.empty())
		return NULL;

	char *out = (char *)malloc(result.size() + 1);
	if (!out)
		return NULL;
	memcpy(out, result.c_str(), result.size() + 1);
	return out;
}


/* ------------------------------------------------------------------ */
/*  Raw send/receive                                                  */
/* ------------------------------------------------------------------ */

extern "C" int
tuya_send(tuya_device_t *dev, unsigned char *buf, int size)
{
	if (!dev || !buf)
		return -1;
	return dev->api->send(buf, size);
}

extern "C" int
tuya_receive(tuya_device_t *dev, unsigned char *buf,
                int maxsize, int minsize)
{
	if (!dev || !buf)
		return -1;
	return dev->api->receive(buf, maxsize, minsize > 0 ? minsize : 30);
}


/* ------------------------------------------------------------------ */
/*  High-level round-trip operations                                  */
/* ------------------------------------------------------------------ */

/*
 * Internal helper: generate payload, build message, send, receive,
 * decode.  Returns malloc'd JSON string or NULL.
 */
static char *
round_trip(tuya_device_t *dev, enum tuya_command cmd,
           const char *dps_json)
{
	if (!dev || !dev->device_id || !dev->local_key)
		return NULL;

	std::string dp = dps_json ? std::string(dps_json) : std::string();
	std::string payload_str = dev->api->GeneratePayload(
	    (uint8_t)cmd, std::string(dev->device_id), dp);
	if (payload_str.empty())
		return NULL;

	int len = dev->api->BuildTuyaMessage(dev->buf, (uint8_t)cmd,
	              payload_str, std::string(dev->local_key));
	if (len < 0)
		return NULL;

	int n = dev->api->send(dev->buf, len);
	if (n < 0)
		return NULL;

	usleep(200000);

	n = dev->api->receive(dev->buf, TUYA_RECOMMENDED_BUFSIZE, 30);
	if (n <= 0)
		return NULL;

	std::string result = dev->api->DecodeTuyaMessage(
	    dev->buf, n, std::string(dev->local_key));
	if (result.empty())
		return NULL;

	char *out = (char *)malloc(result.size() + 1);
	if (!out)
		return NULL;
	memcpy(out, result.c_str(), result.size() + 1);
	return out;
}

extern "C" char *
tuya_set_value_bool(tuya_device_t *dev, int dp, bool value)
{
	char dps[64];
	snprintf(dps, sizeof(dps), "{\"%d\":%s}", dp,
	    value ? "true" : "false");
	return round_trip(dev, TUYA_CMD_CONTROL, dps);
}

extern "C" char *
tuya_set_value_int(tuya_device_t *dev, int dp, int value)
{
	char dps[64];
	snprintf(dps, sizeof(dps), "{\"%d\":%d}", dp, value);
	return round_trip(dev, TUYA_CMD_CONTROL, dps);
}

extern "C" char *
tuya_set_value_string(tuya_device_t *dev, int dp, const char *value)
{
	if (!value)
		return NULL;
	char dps[256];
	snprintf(dps, sizeof(dps), "{\"%d\":\"%s\"}", dp, value);
	return round_trip(dev, TUYA_CMD_CONTROL, dps);
}

extern "C" char *
tuya_set_value_float(tuya_device_t *dev, int dp, double value)
{
	char dps[64];
	snprintf(dps, sizeof(dps), "{\"%d\":%g}", dp, value);
	return round_trip(dev, TUYA_CMD_CONTROL, dps);
}

extern "C" char *
tuya_turn_on(tuya_device_t *dev, int switch_dp)
{
	return tuya_set_value_bool(dev, switch_dp, true);
}

extern "C" char *
tuya_turn_off(tuya_device_t *dev, int switch_dp)
{
	return tuya_set_value_bool(dev, switch_dp, false);
}

extern "C" char *
tuya_status(tuya_device_t *dev)
{
	return round_trip(dev, TUYA_CMD_DP_QUERY, "");
}

extern "C" char *
tuya_heartbeat(tuya_device_t *dev)
{
	return round_trip(dev, TUYA_CMD_HEART_BEAT, "");
}


/* ------------------------------------------------------------------ */
/*  Memory management                                                 */
/* ------------------------------------------------------------------ */

extern "C" void
tuya_free_string(char *str)
{
	free(str);
}
