/*
 * seatuya - C wrapper for the tuyapp C++ Tuya library
 *
 * Copyright (c) 2026, David Walther <david@clearbrookdistillery.com>
 * BSD-2-Clause — see COPYING for details.
 */

#include "seatuya.h"
#include "tuyaAPI.hpp"

#include <cstdlib>
#include <cstring>
#include <string>

struct seatuya_device {
	tuyaAPI *api;
};


/* ------------------------------------------------------------------ */
/*  Version                                                           */
/* ------------------------------------------------------------------ */

extern "C" const char *
seatuya_version(void)
{
	return "0.1.0";
}


/* ------------------------------------------------------------------ */
/*  Lifecycle                                                         */
/* ------------------------------------------------------------------ */

extern "C" seatuya_device_t *
seatuya_create(const char *version)
{
	if (!version)
		return NULL;

	tuyaAPI *api = tuyaAPI::create(std::string(version));
	if (!api)
		return NULL;

	seatuya_device_t *dev = (seatuya_device_t *)malloc(sizeof(*dev));
	if (!dev) {
		delete api;
		return NULL;
	}
	dev->api = api;
	return dev;
}

extern "C" void
seatuya_destroy(seatuya_device_t *dev)
{
	if (!dev)
		return;
	delete dev->api;
	free(dev);
}


/* ------------------------------------------------------------------ */
/*  Connection                                                        */
/* ------------------------------------------------------------------ */

extern "C" int
seatuya_connect(seatuya_device_t *dev, const char *hostname)
{
	if (!dev || !hostname)
		return 0;
	return dev->api->ConnectToDevice(std::string(hostname)) ? 1 : 0;
}

extern "C" void
seatuya_disconnect(seatuya_device_t *dev)
{
	if (dev)
		dev->api->disconnect();
}

extern "C" int
seatuya_is_connected(seatuya_device_t *dev)
{
	if (!dev)
		return 0;
	return dev->api->isConnected() ? 1 : 0;
}


/* ------------------------------------------------------------------ */
/*  Session negotiation                                               */
/* ------------------------------------------------------------------ */

extern "C" int
seatuya_negotiate_session(seatuya_device_t *dev, const char *local_key)
{
	if (!dev || !local_key)
		return 0;
	return dev->api->NegotiateSession(std::string(local_key)) ? 1 : 0;
}

extern "C" int
seatuya_negotiate_session_start(seatuya_device_t *dev, const char *local_key)
{
	if (!dev || !local_key)
		return 0;
	return dev->api->NegotiateSessionStart(std::string(local_key)) ? 1 : 0;
}

extern "C" int
seatuya_negotiate_session_finalize(seatuya_device_t *dev,
                                   unsigned char *buf, int size,
                                   const char *local_key)
{
	if (!dev || !buf || !local_key)
		return 0;
	return dev->api->NegotiateSessionFinalize(buf, size,
	           std::string(local_key)) ? 1 : 0;
}


/* ------------------------------------------------------------------ */
/*  State queries                                                     */
/* ------------------------------------------------------------------ */

extern "C" enum seatuya_protocol
seatuya_get_protocol(seatuya_device_t *dev)
{
	if (!dev)
		return SEATUYA_PROTO_V33;

	switch (dev->api->getProtocol()) {
	case tuyaAPI::Protocol::v31: return SEATUYA_PROTO_V31;
	case tuyaAPI::Protocol::v33: return SEATUYA_PROTO_V33;
	case tuyaAPI::Protocol::v34: return SEATUYA_PROTO_V34;
	case tuyaAPI::Protocol::v35: return SEATUYA_PROTO_V35;
	}
	return SEATUYA_PROTO_V33;
}

extern "C" enum seatuya_session_state
seatuya_get_session_state(seatuya_device_t *dev)
{
	if (!dev)
		return SEATUYA_SESSION_INVALID;

	switch (dev->api->getSessionState()) {
	case Tuya::Session::INVALID:      return SEATUYA_SESSION_INVALID;
	case Tuya::Session::STARTING:     return SEATUYA_SESSION_STARTING;
	case Tuya::Session::FINALIZING:   return SEATUYA_SESSION_FINALIZING;
	case Tuya::Session::ESTABLISHED:  return SEATUYA_SESSION_ESTABLISHED;
	}
	return SEATUYA_SESSION_INVALID;
}

extern "C" enum seatuya_socket_state
seatuya_get_socket_state(seatuya_device_t *dev)
{
	if (!dev)
		return SEATUYA_SOCK_DISCONNECTED;

	switch (dev->api->getSocketState()) {
	case Tuya::TCP::Socket::NO_SUCH_HOST:  return SEATUYA_SOCK_NO_SUCH_HOST;
	case Tuya::TCP::Socket::NO_SOCK_AVAIL: return SEATUYA_SOCK_NO_SOCK_AVAIL;
	case Tuya::TCP::Socket::FAILED:        return SEATUYA_SOCK_FAILED;
	case Tuya::TCP::Socket::DISCONNECTED:  return SEATUYA_SOCK_DISCONNECTED;
	case Tuya::TCP::Socket::CONNECTING:    return SEATUYA_SOCK_CONNECTING;
	case Tuya::TCP::Socket::CONNECTED:     return SEATUYA_SOCK_CONNECTED;
	case Tuya::TCP::Socket::READY:         return SEATUYA_SOCK_READY;
	case Tuya::TCP::Socket::RECEIVING:     return SEATUYA_SOCK_RECEIVING;
	}
	return SEATUYA_SOCK_DISCONNECTED;
}

extern "C" int
seatuya_get_last_error(seatuya_device_t *dev)
{
	if (!dev)
		return -1;
	return dev->api->getlasterror();
}


/* ------------------------------------------------------------------ */
/*  Async mode                                                        */
/* ------------------------------------------------------------------ */

extern "C" void
seatuya_set_async_mode(seatuya_device_t *dev, int async)
{
	if (dev)
		dev->api->setAsyncMode(async != 0);
}

extern "C" int
seatuya_is_socket_readable(seatuya_device_t *dev)
{
	if (!dev)
		return 0;
	return dev->api->isSocketReadable() ? 1 : 0;
}

extern "C" int
seatuya_is_socket_writable(seatuya_device_t *dev)
{
	if (!dev)
		return 0;
	return dev->api->isSocketWritable() ? 1 : 0;
}

extern "C" int
seatuya_set_session_ready(seatuya_device_t *dev)
{
	if (!dev)
		return 0;
	return dev->api->setSessionReady() ? 1 : 0;
}


/* ------------------------------------------------------------------ */
/*  Message building and decoding                                     */
/* ------------------------------------------------------------------ */

extern "C" int
seatuya_build_message(seatuya_device_t *dev, unsigned char *buf,
                      enum seatuya_command cmd, const char *payload,
                      const char *key)
{
	if (!dev || !buf || !payload || !key)
		return -1;
	return dev->api->BuildTuyaMessage(buf, (uint8_t)cmd,
	           std::string(payload), std::string(key));
}

extern "C" char *
seatuya_decode_message(seatuya_device_t *dev, unsigned char *buf,
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
seatuya_generate_payload(seatuya_device_t *dev,
                         enum seatuya_command cmd,
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
seatuya_send(seatuya_device_t *dev, unsigned char *buf, int size)
{
	if (!dev || !buf)
		return -1;
	return dev->api->send(buf, size);
}

extern "C" int
seatuya_receive(seatuya_device_t *dev, unsigned char *buf,
                int maxsize, int minsize)
{
	if (!dev || !buf)
		return -1;
	return dev->api->receive(buf, maxsize, minsize > 0 ? minsize : 30);
}


/* ------------------------------------------------------------------ */
/*  Memory management                                                 */
/* ------------------------------------------------------------------ */

extern "C" void
seatuya_free_string(char *str)
{
	free(str);
}
