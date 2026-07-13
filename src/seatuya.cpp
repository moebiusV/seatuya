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
#include <ctime>
#include <string>
#include <unistd.h>

struct tuya_device {
	tuyaAPI *api;
	char *device_id;
	char *local_key;
	char *ip;
	int retry_limit;
	int retry_delay_ms;
	/*
	 * device22: firmware found on many devices with 22-character
	 * device ids.  Reports protocol 3.3 but ignores DP_QUERY (10)
	 * and CONTROL (7); status must be requested with CONTROL_NEW
	 * (13) carrying a null-valued DP map, and writes must also use
	 * CONTROL_NEW.  Enabled explicitly via tuya_set_device22()
	 * (auto-detection misfires; see tuya-local's "3.22").
	 */
	bool device22;
	char *dps_map;          /* e.g. {"101":null,"102":null,...}   */
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
tuya_create(const char *device_id, const char *address,
            const char *local_key, const char *version)
{
	tuya_device_t *dev = tuya_alloc(version);
	if (!dev)
		return NULL;

	tuya_set_credentials(dev, device_id, local_key);

	if (!tuya_connect(dev, address)) {
		tuya_destroy(dev);
		return NULL;
	}

	if (!tuya_negotiate_session(dev, local_key)) {
		tuya_disconnect(dev);
		tuya_destroy(dev);
		return NULL;
	}

	return dev;
}

extern "C" tuya_device_t *
tuya_alloc(const char *version)
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
	dev->retry_limit = TUYA_DEFAULT_RETRY_LIMIT;
	dev->retry_delay_ms = TUYA_DEFAULT_RETRY_DELAY_MS;
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
	free(dev->dps_map);
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

extern "C" void
tuya_set_retry_limit(tuya_device_t *dev, int limit)
{
	if (dev)
		dev->retry_limit = limit;
}

extern "C" void
tuya_set_retry_delay(tuya_device_t *dev, int delay_ms)
{
	if (dev)
		dev->retry_delay_ms = delay_ms;
}

extern "C" int
tuya_get_retry_limit(tuya_device_t *dev)
{
	return dev ? dev->retry_limit : 0;
}

extern "C" int
tuya_get_retry_delay(tuya_device_t *dev)
{
	return dev ? dev->retry_delay_ms : 0;
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

/*
 * Native payload generation.
 *
 * tuyapp's tuyaAPI::GeneratePayload() substitutes @devid@/@dps@/@now@
 * with std::string::replace() at hardcoded byte offsets.  For a
 * 22-character device id the HEART_BEAT template's offsets are wrong
 * and the result is malformed JSON (the '@' survives and the closing
 * quotes are consumed).  A malformed inner payload is encrypted into
 * a valid 3.3 frame, so the device silently drops it -- which is
 * indistinguishable from a wrong-key drop and defeats heartbeat as a
 * key oracle.
 *
 * This replacement does token search-and-replace, so it is correct
 * for any device id length and cannot drift.  It is used in place of
 * dev->api->GeneratePayload() everywhere in the shim, so seatuya does
 * not depend on tuyapp's offset bookkeeping.
 */
static void
replace_all(std::string &s, const std::string &from, const std::string &to)
{
	if (from.empty())
		return;
	for (size_t pos = 0;
	     (pos = s.find(from, pos)) != std::string::npos;
	     pos += to.size())
		s.replace(pos, from.size(), to);
}

static std::string
gen_payload(enum tuya_command cmd, const std::string &id,
            const std::string &dps)
{
	std::string now = std::to_string((long long)time(NULL));
	std::string p;

	switch (cmd) {
	case TUYA_CMD_HEART_BEAT:
		p = "{\"gwId\":\"@devid@\",\"devId\":\"@devid@\"}";
		break;
	case TUYA_CMD_DP_QUERY:
		p = "{\"gwId\":\"@devid@\",\"devId\":\"@devid@\","
		    "\"uid\":\"@devid@\",\"t\":\"@now@\"}";
		break;
	case TUYA_CMD_CONTROL:
		p = "{\"devId\":\"@devid@\",\"uid\":\"@devid@\","
		    "\"dps\":@dps@,\"t\":\"@now@\"}";
		break;
	case TUYA_CMD_DP_QUERY_NEW:
		p = "{\"devId\":\"@devid@\",\"uid\":\"@devid@\","
		    "\"t\":\"@now@\"}";
		break;
	case TUYA_CMD_CONTROL_NEW:
		p = "{\"protocol\":5,\"t\":@now@,\"data\":{\"dps\":@dps@}}";
		break;
	default:
		return std::string();
	}

	replace_all(p, "@devid@", id);
	replace_all(p, "@dps@", dps);
	replace_all(p, "@now@", now);
	return p;
}


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
	std::string result = gen_payload(cmd,
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
 *
 * Command remapping (mirrors tinytuya):
 *
 *   device22:        DP_QUERY -> CONTROL_NEW with null-DP map,
 *                    CONTROL  -> CONTROL_NEW
 *   protocol 3.4/3.5: DP_QUERY -> DP_QUERY_NEW,
 *                    CONTROL  -> CONTROL_NEW
 *
 * Status replies do not always arrive as a direct answer to the
 * query frame: device22 firmware acks CONTROL_NEW with an empty
 * payload and pushes the DP state as a separate STATUS (8) frame.
 * For status queries we therefore read up to a few frames and
 * return the first one carrying a JSON object.
 *
 * On socket timeout or network error, closes the connection and
 * retries up to dev->retry_limit times (matching tinytuya's
 * _send_receive() behavior).
 */
static char *
round_trip(tuya_device_t *dev, enum tuya_command cmd,
           const char *dps_json)
{
	if (!dev || !dev->device_id || !dev->local_key)
		return NULL;

	std::string dp = dps_json ? std::string(dps_json) : std::string();
	std::string key(dev->local_key);
	std::string id(dev->device_id);

	bool is_query = (cmd == TUYA_CMD_DP_QUERY);
	bool new_cmdset =
	    (dev->api->getProtocol() == tuyaAPI::Protocol::v34 ||
	     dev->api->getProtocol() == tuyaAPI::Protocol::v35);

	if (dev->device22) {
		if (cmd == TUYA_CMD_DP_QUERY) {
			cmd = TUYA_CMD_CONTROL_NEW;
			dp = dev->dps_map ? std::string(dev->dps_map)
			                  : std::string("{\"1\":null}");
		} else if (cmd == TUYA_CMD_CONTROL) {
			cmd = TUYA_CMD_CONTROL_NEW;
		}
	} else if (new_cmdset) {
		if (cmd == TUYA_CMD_DP_QUERY)
			cmd = TUYA_CMD_DP_QUERY_NEW;
		else if (cmd == TUYA_CMD_CONTROL)
			cmd = TUYA_CMD_CONTROL_NEW;
	}

	std::string payload_str = gen_payload(cmd, id, dp);
	if (payload_str.empty())
		return NULL;

	int retries = 0;
	for (;;) {
		int len = dev->api->BuildTuyaMessage(dev->buf, (uint8_t)cmd,
		              payload_str, key);
		if (len < 0)
			return NULL;

		int n = dev->api->send(dev->buf, len);
		if (n >= 0) {
			/*
			 * Status queries may be answered by a later
			 * frame than the first; keep reading briefly.
			 */
			int recv_attempts = is_query ? 3 : 1;
			for (int r = 0; r < recv_attempts; r++) {
				usleep(200000);
				n = dev->api->receive(dev->buf,
				        TUYA_RECOMMENDED_BUFSIZE, 30);
				if (n <= 0)
					break;
				std::string result =
				    dev->api->DecodeTuyaMessage(
				        dev->buf, n, key);
				if (result.empty())
					continue;
				if (is_query &&
				    result.find('{') == std::string::npos &&
				    r + 1 < recv_attempts)
					continue;
				char *out = (char *)malloc(
				    result.size() + 1);
				if (!out)
					return NULL;
				memcpy(out, result.c_str(),
				    result.size() + 1);
				return out;
			}
		}

		/* send or receive failed -- retry? */
		if (retries >= dev->retry_limit)
			return NULL;
		retries++;
		dev->api->disconnect();
		usleep(dev->retry_delay_ms * 1000);
		if (!tuya_reconnect(dev))
			return NULL;
	}
}

extern "C" void
tuya_set_device22(tuya_device_t *dev, const char *null_dps_json)
{
	if (!dev)
		return;
	free(dev->dps_map);
	dev->dps_map = NULL;
	if (null_dps_json) {
		dev->device22 = true;
		dev->dps_map = dup_str(null_dps_json);
	} else {
		dev->device22 = false;
	}
}

extern "C" bool
tuya_is_device22(const tuya_device_t *dev)
{
	return dev ? dev->device22 : false;
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
