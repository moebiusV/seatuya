/*
 * wizard-common.c — Shared logic for seatuya-wizard.
 *
 * Contains the Tuya Cloud API client, UDP discovery, config I/O,
 * JSON helpers, crypto helpers, and the wizard main flow.
 * The HTTPS transport is provided by the TLS-backend-specific file
 * (wizard-https-libtls.c or wizard-https-openssl.c).
 *
 * Copyright (c) 2026, David Walther <david@clearbrookdistillery.com>
 * BSD-2-Clause
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "wizard-common.h"
#include <seatuya.h>

#include <arpa/inet.h>
#include <ctype.h>
#include <netdb.h>
#include <netinet/in.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/sha.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

/* ------------------------------------------------------------------ */
/*  Simple growable string buffer                                     */
/* ------------------------------------------------------------------ */

void
strbuf_init(struct strbuf *sb)
{
	sb->cap = 1024;
	sb->data = malloc(sb->cap);
	sb->data[0] = '\0';
	sb->len = 0;
}

void
strbuf_append(struct strbuf *sb, const char *s, size_t n)
{
	while (sb->len + n + 1 > sb->cap) {
		sb->cap *= 2;
		sb->data = realloc(sb->data, sb->cap);
	}
	memcpy(sb->data + sb->len, s, n);
	sb->len += n;
	sb->data[sb->len] = '\0';
}

void
strbuf_free(struct strbuf *sb)
{
	free(sb->data);
	sb->data = NULL;
	sb->len = sb->cap = 0;
}

/* ------------------------------------------------------------------ */
/*  Minimal JSON string extraction                                    */
/* ------------------------------------------------------------------ */

static const char *
json_get_string(const char *json, const char *key, char *out, int outsize)
{
	char needle[256];
	snprintf(needle, sizeof(needle), "\"%s\"", key);
	const char *p = strstr(json, needle);
	if (!p) return NULL;
	p += strlen(needle);
	while (*p == ' ' || *p == ':' || *p == '\t') p++;
	if (*p != '"') return NULL;
	const char *start = ++p;
	const char *end = strchr(start, '"');
	if (!end) return NULL;
	int len = end - start;
	if (len >= outsize) len = outsize - 1;
	memcpy(out, start, len);
	out[len] = '\0';
	return out;
}

static bool
json_get_bool(const char *json, const char *key)
{
	char needle[256];
	snprintf(needle, sizeof(needle), "\"%s\"", key);
	const char *p = strstr(json, needle);
	if (!p) return false;
	p += strlen(needle);
	while (*p == ' ' || *p == ':' || *p == '\t') p++;
	return (strncmp(p, "true", 4) == 0);
}

static const char *
json_get_result_array(const char *json)
{
	const char *p = strstr(json, "\"result\"");
	if (!p) return NULL;
	p += 8;
	while (*p && *p != '[') p++;
	return (*p == '[') ? p : NULL;
}

static const char *
json_skip_object(const char *p)
{
	if (*p != '{') return NULL;
	int depth = 1;
	bool in_string = false;
	p++;
	while (*p && depth > 0) {
		if (in_string) {
			if (*p == '\\') { p++; }
			else if (*p == '"') { in_string = false; }
		} else {
			if (*p == '"') in_string = true;
			else if (*p == '{') depth++;
			else if (*p == '}') depth--;
		}
		p++;
	}
	return p;
}

/* ------------------------------------------------------------------ */
/*  Tuya Cloud API region mapping                                     */
/* ------------------------------------------------------------------ */

static const char *
region_to_host(const char *region)
{
	if (!region) return "openapi.tuyaus.com";
	if (strcmp(region, "us") == 0 || strcmp(region, "az") == 0)
		return "openapi.tuyaus.com";
	if (strcmp(region, "us-e") == 0 || strcmp(region, "ue") == 0)
		return "openapi-ueaz.tuyaus.com";
	if (strcmp(region, "eu") == 0)
		return "openapi.tuyaeu.com";
	if (strcmp(region, "eu-w") == 0 || strcmp(region, "we") == 0)
		return "openapi-weaz.tuyaeu.com";
	if (strcmp(region, "cn") == 0 || strcmp(region, "ay") == 0)
		return "openapi.tuyacn.com";
	if (strcmp(region, "in") == 0)
		return "openapi.tuyain.com";
	if (strcmp(region, "sg") == 0)
		return "openapi-sg.iotbing.com";
	return "openapi.tuyaus.com";
}

/* ------------------------------------------------------------------ */
/*  HMAC-SHA256                                                       */
/* ------------------------------------------------------------------ */

static void
hmac_sha256(const char *key, int keylen,
            const char *msg, int msglen,
            unsigned char *out)
{
	unsigned int len = 32;
	HMAC(EVP_sha256(),
	     (const unsigned char *)key, keylen,
	     (const unsigned char *)msg, msglen,
	     out, &len);
}

static void
sha256_hex(const char *data, int datalen, char *out)
{
	unsigned char hash[SHA256_DIGEST_LENGTH];
	SHA256((const unsigned char *)data, datalen, hash);
	for (int i = 0; i < SHA256_DIGEST_LENGTH; i++)
		sprintf(out + i * 2, "%02x", hash[i]);
	out[SHA256_DIGEST_LENGTH * 2] = '\0';
}

static void
to_upper_hex(const unsigned char *in, int inlen, char *out)
{
	for (int i = 0; i < inlen; i++)
		sprintf(out + i * 2, "%02X", in[i]);
	out[inlen * 2] = '\0';
}

/* ------------------------------------------------------------------ */
/*  HTTP helpers                                                      */
/* ------------------------------------------------------------------ */

void
build_http_request(struct strbuf *req, const char *host, const char *method,
                   const char *path, const char **header_keys,
                   const char **header_vals, int nheaders, const char *body)
{
	char line[1024];
	int n;

	n = snprintf(line, sizeof(line), "%s %s HTTP/1.1\r\n", method, path);
	strbuf_append(req, line, n);
	n = snprintf(line, sizeof(line), "Host: %s\r\n", host);
	strbuf_append(req, line, n);

	for (int i = 0; i < nheaders; i++) {
		n = snprintf(line, sizeof(line), "%s: %s\r\n",
		             header_keys[i], header_vals[i]);
		strbuf_append(req, line, n);
	}

	if (body && body[0]) {
		n = snprintf(line, sizeof(line), "Content-Length: %d\r\n",
		             (int)strlen(body));
		strbuf_append(req, line, n);
	}

	strbuf_append(req, "Connection: close\r\n\r\n", 21);

	if (body && body[0])
		strbuf_append(req, body, strlen(body));
}

char *
extract_json_body(struct strbuf *resp)
{
	char *body_start = strstr(resp->data, "\r\n\r\n");
	if (!body_start) return NULL;
	body_start += 4;

	char *json_start = strchr(body_start, '{');
	if (!json_start) return NULL;
	return strdup(json_start);
}

/* ------------------------------------------------------------------ */
/*  Tuya Cloud API client                                             */
/* ------------------------------------------------------------------ */

struct tuya_cloud {
	char api_key[128];
	char api_secret[128];
	char api_region[16];
	char api_device_id[128];
	char token[256];
	const char *host;
};

/* forward declarations (used before their definitions below) */
static char *tuya_api_call_r(struct tuya_cloud *cloud, const char *method,
                             const char *uri, const char *body, bool retrying);
static bool tuya_get_token(struct tuya_cloud *cloud);

static char *
tuya_api_call(struct tuya_cloud *cloud, const char *method,
              const char *uri, const char *body)
{
	return tuya_api_call_r(cloud, method, uri, body, false);
}

static char *
tuya_api_call_r(struct tuya_cloud *cloud, const char *method,
                const char *uri, const char *body, bool retrying)
{
	char path[512];
	/*
	 * uri is normally relative to /v1.0/.  A leading '/' passes the
	 * path through verbatim, which is how the /v2.0/cloud/thing/...
	 * (thing data model / shadow) endpoints are reached.  The sign
	 * algorithm covers the full path either way.
	 */
	if (uri[0] == '/')
		snprintf(path, sizeof(path), "%s", uri);
	else
		snprintf(path, sizeof(path), "/v1.0/%s", uri);

	struct timeval tv;
	gettimeofday(&tv, NULL);
	long long now = (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
	char ts[32];
	snprintf(ts, sizeof(ts), "%lld", now);

	char content_hash[65];
	sha256_hex(body ? body : "", body ? (int)strlen(body) : 0, content_hash);

	/* Build headers — match tinytuya's new sign algorithm */
	const char *hkeys[8];
	const char *hvals[8];
	char sig_headers_buf[256];
	int nheaders = 0;

	hkeys[nheaders] = "client_id";
	hvals[nheaders] = cloud->api_key;
	nheaders++;

	/* sign placeholder — filled after signature is computed */
	hkeys[nheaders] = "sign";
	hvals[nheaders] = "";
	nheaders++;

	hkeys[nheaders] = "t";
	hvals[nheaders] = ts;
	nheaders++;

	hkeys[nheaders] = "sign_method";
	hvals[nheaders] = "HMAC-SHA256";
	nheaders++;

	hkeys[nheaders] = "mode";
	hvals[nheaders] = "cors";
	nheaders++;

	if (cloud->token[0]) {
		hkeys[nheaders] = "access_token";
		hvals[nheaders] = cloud->token;
		nheaders++;
	} else {
		/* token request: send secret as header (tinytuya compat) */
		hkeys[nheaders] = "secret";
		hvals[nheaders] = cloud->api_secret;
		nheaders++;
	}

	if (body && body[0]) {
		hkeys[nheaders] = "Content-type";
		hvals[nheaders] = "application/json";
		nheaders++;
	}

	/* Build Signature-Headers: colon-separated list of header keys */
	sig_headers_buf[0] = '\0';
	for (int i = 0; i < nheaders; i++) {
		if (i > 0) strcat(sig_headers_buf, ":");
		strcat(sig_headers_buf, hkeys[i]);
	}
	hkeys[nheaders] = "Signature-Headers";
	hvals[nheaders] = sig_headers_buf;
	nheaders++;

	/* Build HMAC payload — tinytuya new sign algorithm */
	struct strbuf payload;
	strbuf_init(&payload);

	strbuf_append(&payload, cloud->api_key, strlen(cloud->api_key));
	if (cloud->token[0])
		strbuf_append(&payload, cloud->token, strlen(cloud->token));
	strbuf_append(&payload, ts, strlen(ts));
	strbuf_append(&payload, method, strlen(method));
	strbuf_append(&payload, "\n", 1);
	strbuf_append(&payload, content_hash, strlen(content_hash));
	strbuf_append(&payload, "\n", 1);
	/* header lines (all headers except Signature-Headers itself) */
	for (int i = 0; i < nheaders - 1; i++) {
		if (strcmp(hkeys[i], "Signature-Headers") == 0) continue;
		strbuf_append(&payload, hkeys[i], strlen(hkeys[i]));
		strbuf_append(&payload, ":", 1);
		strbuf_append(&payload, hvals[i], strlen(hvals[i]));
		strbuf_append(&payload, "\n", 1);
	}
	strbuf_append(&payload, "\n", 1);
	strbuf_append(&payload, path, strlen(path));

	unsigned char hmac_raw[32];
	hmac_sha256(cloud->api_secret, strlen(cloud->api_secret),
	            payload.data, payload.len, hmac_raw);
	strbuf_free(&payload);

	char signature[65];
	to_upper_hex(hmac_raw, 32, signature);
	hvals[1] = signature; /* fill in sign placeholder */

	char *resp = https_request(cloud->host, method, path,
	                            hkeys, hvals, nheaders, body);

	/* Token refresh on expiry — match tinytuya behaviour */
	if (resp && strstr(resp, "token invalid") &&
	    cloud->token[0] && !retrying) {
		free(resp);
		if (tuya_get_token(cloud))
			return tuya_api_call_r(cloud, method, uri,
			                       body, true);
		return NULL;
	}

	return resp;
}

static bool
tuya_get_token(struct tuya_cloud *cloud)
{
	cloud->token[0] = '\0';
	char *resp = tuya_api_call(cloud, "GET", "token?grant_type=1", NULL);
	if (!resp) {
		fprintf(stderr, "error: failed to connect to Tuya Cloud\n");
		return false;
	}

	if (!json_get_bool(resp, "success")) {
		char msg[256] = {0};
		json_get_string(resp, "msg", msg, sizeof(msg));
		fprintf(stderr, "error: token request failed: %s\n", msg);
		free(resp);
		return false;
	}

	json_get_string(resp, "access_token", cloud->token, sizeof(cloud->token));
	free(resp);

	if (!cloud->token[0]) {
		fprintf(stderr, "error: no access_token in response\n");
		return false;
	}

	return true;
}

static char *
tuya_get_uid(struct tuya_cloud *cloud, const char *device_id)
{
	char uri[256];
	snprintf(uri, sizeof(uri), "devices/%s", device_id);
	char *resp = tuya_api_call(cloud, "GET", uri, NULL);
	if (!resp) return NULL;

	if (!json_get_bool(resp, "success")) {
		char msg[256] = {0};
		json_get_string(resp, "msg", msg, sizeof(msg));
		fprintf(stderr, "error: get device failed: %s\n", msg);
		free(resp);
		return NULL;
	}

	char uid[128] = {0};
	json_get_string(resp, "uid", uid, sizeof(uid));
	free(resp);
	return uid[0] ? strdup(uid) : NULL;
}

/* ------------------------------------------------------------------ */
/*  Device record                                                     */
/* ------------------------------------------------------------------ */

struct tuya_device {
	char id[128];
	char name[256];
	char key[128];
	char product_id[128];
	char ip[64];
	char version[16];
	bool sub;
};

static int
tuya_get_devices(struct tuya_cloud *cloud, struct tuya_device *devices,
                 int max_devices)
{
	char *uid = tuya_get_uid(cloud, cloud->api_device_id);
	if (!uid) {
		fprintf(stderr, "error: could not get UID for device %s\n",
		    cloud->api_device_id);
		return -1;
	}

	char uri[256];
	snprintf(uri, sizeof(uri), "users/%s/devices", uid);
	free(uid);

	char *resp = tuya_api_call(cloud, "GET", uri, NULL);
	if (!resp) return -1;

	if (!json_get_bool(resp, "success")) {
		char msg[256] = {0};
		json_get_string(resp, "msg", msg, sizeof(msg));
		fprintf(stderr, "error: get devices failed: %s\n", msg);
		free(resp);
		return -1;
	}

	const char *arr = json_get_result_array(resp);
	if (!arr) {
		free(resp);
		return 0;
	}

	int count = 0;
	const char *p = arr + 1;

	while (*p && count < max_devices) {
		while (*p && *p != '{') p++;
		if (*p != '{') break;

		const char *end = json_skip_object(p);
		if (!end) break;

		int objlen = end - p;
		char *obj = malloc(objlen + 1);
		memcpy(obj, p, objlen);
		obj[objlen] = '\0';

		struct tuya_device *d = &devices[count];
		memset(d, 0, sizeof(*d));

		json_get_string(obj, "id", d->id, sizeof(d->id));
		json_get_string(obj, "name", d->name, sizeof(d->name));
		json_get_string(obj, "local_key", d->key, sizeof(d->key));
		json_get_string(obj, "product_id", d->product_id, sizeof(d->product_id));
		d->sub = json_get_bool(obj, "sub");

		free(obj);

		if (d->id[0])
			count++;

		p = end;
	}

	free(resp);
	return count;
}

/* ------------------------------------------------------------------ */
/*  UDP discovery (local network scan)                                */
/* ------------------------------------------------------------------ */

static const char *
find_json_in_frame(const char *data, int datalen)
{
	for (int i = 0; i < datalen; i++)
		if (data[i] == '{')
			return &data[i];
	return NULL;
}

/* ------------------------------------------------------------------ */
/*  Thing Data Model (v2.0 "shadow") endpoints                        */
/* ------------------------------------------------------------------ */

/*
 * Newer Tuya products (including category "mzj") are migrated to the
 * Thing Data Model.  For these, the v1.0 DP endpoints authenticate
 * but return empty results:
 *
 *     /v1.0/devices/{id}/status      -> {"result":[]}
 *     /v1.0/devices/{id}/functions   -> {"functions":[]}
 *     .../commands                   -> error 2008
 *
 * because the device exposes *properties*, not *functions*.  The
 * working endpoints are:
 *
 *     GET  /v2.0/cloud/thing/{id}/shadow/properties        (read)
 *     GET  /v2.0/cloud/thing/{id}/model                    (schema)
 *     POST /v2.0/cloud/thing/{id}/shadow/properties/issue  (write)
 *
 * The issue body wraps the property map as a *string*:
 *     {"properties":"{\"temp_set\":500}"}
 */

static char *
cloud_thing_model(struct tuya_cloud *cloud, const char *device_id)
{
	char path[256];
	snprintf(path, sizeof(path), "/v2.0/cloud/thing/%s/model",
	    device_id);
	return tuya_api_call(cloud, "GET", path, NULL);
}

static char *
cloud_shadow_properties(struct tuya_cloud *cloud, const char *device_id)
{
	char path[256];
	snprintf(path, sizeof(path),
	    "/v2.0/cloud/thing/%s/shadow/properties", device_id);
	return tuya_api_call(cloud, "GET", path, NULL);
}

static char *
cloud_shadow_issue(struct tuya_cloud *cloud, const char *device_id,
                   const char *properties_json)
{
	char path[256];
	snprintf(path, sizeof(path),
	    "/v2.0/cloud/thing/%s/shadow/properties/issue", device_id);

	/* wrap and escape the property map as a JSON string value */
	struct strbuf body;
	strbuf_init(&body);
	strbuf_append(&body, "{\"properties\":\"", 15);
	for (const char *p = properties_json; *p; p++) {
		if (*p == '"' || *p == '\\')
			strbuf_append(&body, "\\", 1);
		strbuf_append(&body, p, 1);
	}
	strbuf_append(&body, "\"}", 2);

	char *resp = tuya_api_call(cloud, "POST", path, body.data);
	strbuf_free(&body);
	return resp;
}

/*
 * MD5("yGAdlopoPVldABfn") -- the static key every Tuya SDK uses to
 * AES-128-ECB encrypt UDP broadcasts on port 6667.
 */
static const unsigned char tuya_udpkey[16] = {
	0x6c, 0x1e, 0xc8, 0xe2, 0xbb, 0x9b, 0xb5, 0x9a,
	0xb5, 0x0b, 0x0d, 0xaf, 0x64, 0x9b, 0x41, 0x0a
};

/*
 * Decrypt an AES-128-ECB buffer in place with the static UDP key and
 * strip PKCS#7 padding.  Returns plaintext length or -1.
 */
static int
udp_broadcast_decrypt(unsigned char *buf, int len)
{
	if (len <= 0 || len % 16 != 0)
		return -1;

	EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
	if (!ctx)
		return -1;

	int outlen = 0, tmplen = 0, ok = 0;
	unsigned char *out = malloc(len + 16);
	if (out &&
	    EVP_DecryptInit_ex(ctx, EVP_aes_128_ecb(), NULL,
	                       tuya_udpkey, NULL) == 1 &&
	    EVP_CIPHER_CTX_set_padding(ctx, 0) == 1 &&
	    EVP_DecryptUpdate(ctx, out, &outlen, buf, len) == 1 &&
	    EVP_DecryptFinal_ex(ctx, out + outlen, &tmplen) == 1)
		ok = 1;
	EVP_CIPHER_CTX_free(ctx);
	if (!ok) {
		free(out);
		return -1;
	}
	outlen += tmplen;

	int pad = out[outlen - 1];
	if (pad < 1 || pad > 16 || pad > outlen) {
		free(out);
		return -1;
	}
	outlen -= pad;
	memcpy(buf, out, outlen);
	free(out);
	return outlen;
}

/*
 * Listen for Tuya device broadcasts on all three discovery ports:
 *
 *   6666  protocol 3.1        plaintext
 *   6667  protocol 3.3 / 3.4  AES-128-ECB, static key
 *   7000  protocol 3.5        AES-GCM (presence noted, not decoded)
 *
 * Devices matching entries in devices[] get ip/version filled in;
 * unknown devices are appended up to capacity.  Returns the new
 * device count.
 */
static int
udp_discover(struct tuya_device *devices, int count, int capacity,
             int timeout_secs)
{
	static const int ports[3] = { 6666, 6667, 7000 };
	int socks[3] = { -1, -1, -1 };
	int maxfd = -1;

	for (int i = 0; i < 3; i++) {
		int s = socket(AF_INET, SOCK_DGRAM, 0);
		if (s < 0)
			continue;
		int reuse = 1;
		setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &reuse,
		    sizeof(reuse));
		struct sockaddr_in addr;
		memset(&addr, 0, sizeof(addr));
		addr.sin_family = AF_INET;
		addr.sin_port = htons(ports[i]);
		addr.sin_addr.s_addr = htonl(INADDR_ANY);
		if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
			fprintf(stderr, "bind udp/%d failed\n", ports[i]);
			close(s);
			continue;
		}
		socks[i] = s;
		if (s > maxfd)
			maxfd = s;
	}
	if (maxfd < 0) {
		fprintf(stderr, "no discovery ports could be opened\n");
		return count;
	}

	printf("\nScanning local network on udp 6666/6667/7000 (%ds)...\n",
	    timeout_secs);

	struct timeval deadline;
	gettimeofday(&deadline, NULL);
	deadline.tv_sec += timeout_secs;

	int found = 0;

	for (;;) {
		struct timeval now, tv;
		gettimeofday(&now, NULL);
		if (now.tv_sec > deadline.tv_sec)
			break;

		tv.tv_sec = 1;
		tv.tv_usec = 0;

		fd_set fds;
		FD_ZERO(&fds);
		for (int i = 0; i < 3; i++)
			if (socks[i] >= 0)
				FD_SET(socks[i], &fds);

		if (select(maxfd + 1, &fds, NULL, NULL, &tv) <= 0)
			continue;

		for (int i = 0; i < 3; i++) {
			if (socks[i] < 0 || !FD_ISSET(socks[i], &fds))
				continue;

			unsigned char buf[MAX_BUF];
			struct sockaddr_in sender;
			socklen_t slen = sizeof(sender);
			int n = recvfrom(socks[i], buf, sizeof(buf) - 17, 0,
			                 (struct sockaddr *)&sender, &slen);
			if (n <= 0)
				continue;
			buf[n] = '\0';

			char sender_ip[64];
			inet_ntop(AF_INET, &sender.sin_addr, sender_ip,
			    sizeof(sender_ip));

			if (ports[i] == 7000) {
				/*
				 * v3.5 GCM broadcast; id not recoverable
				 * without a GCM implementation, but the
				 * presence tells us the protocol version.
				 */
				printf("  %-15s  v3.5 broadcast (use "
				       "protocol 3.5)\n", sender_ip);
				continue;
			}

			const char *json = NULL;
			if (ports[i] == 6667) {
				/* 55AA frame: 16 hdr + 4 retcode ...
				 * 4 crc + 4 suffix */
				if (n < 28)
					continue;
				int plen = udp_broadcast_decrypt(&buf[20],
				               n - 28);
				if (plen < 0)
					continue;
				buf[20 + plen] = '\0';
				json = find_json_in_frame((char *)&buf[20],
				           plen);
			} else {
				json = find_json_in_frame((char *)buf, n);
			}
			if (!json)
				continue;

			char gw_id[128] = {0}, ip[64] = {0}, ver[16] = {0};
			json_get_string(json, "gwId", gw_id, sizeof(gw_id));
			if (!gw_id[0])
				continue;
			if (!json_get_string(json, "ip", ip, sizeof(ip)))
				strncpy(ip, sender_ip, sizeof(ip) - 1);
			json_get_string(json, "version", ver, sizeof(ver));

			bool matched = false;
			for (int d = 0; d < count; d++) {
				if (strcmp(devices[d].id, gw_id) != 0)
					continue;
				matched = true;
				if (!devices[d].ip[0]) {
					strncpy(devices[d].ip, ip,
					    sizeof(devices[d].ip) - 1);
					if (ver[0])
						strncpy(devices[d].version,
						    ver,
						    sizeof(devices[d].version) - 1);
					found++;
					printf("  %-40s %s  v%s\n",
					    devices[d].name, ip, ver);
				}
				break;
			}
			if (!matched && count < capacity) {
				struct tuya_device *d = &devices[count];
				memset(d, 0, sizeof(*d));
				strncpy(d->id, gw_id, sizeof(d->id) - 1);
				strncpy(d->ip, ip, sizeof(d->ip) - 1);
				strncpy(d->version, ver,
				    sizeof(d->version) - 1);
				count++;
				found++;
				printf("  %-40s %s  v%s  (not in cloud "
				       "list)\n", gw_id, ip, ver);
			}
		}
	}

	for (int i = 0; i < 3; i++)
		if (socks[i] >= 0)
			close(socks[i]);
	printf("  %d device(s) found on local network.\n", found);
	return count;
}

/* ------------------------------------------------------------------ */
/*  Config file I/O                                                   */
/* ------------------------------------------------------------------ */

static void
load_config(const char *path, struct tuya_cloud *cloud)
{
	FILE *fp = fopen(path, "r");
	if (!fp) return;

	char buf[MAX_BUF];
	size_t n = fread(buf, 1, sizeof(buf) - 1, fp);
	buf[n] = '\0';
	fclose(fp);

	json_get_string(buf, "apiKey", cloud->api_key, sizeof(cloud->api_key));
	json_get_string(buf, "apiSecret", cloud->api_secret, sizeof(cloud->api_secret));
	json_get_string(buf, "apiRegion", cloud->api_region, sizeof(cloud->api_region));
	json_get_string(buf, "apiDeviceID", cloud->api_device_id, sizeof(cloud->api_device_id));
}

static void
save_config(const char *path, struct tuya_cloud *cloud)
{
	FILE *fp = fopen(path, "w");
	if (!fp) {
		fprintf(stderr, "error: cannot write %s: ", path);
		perror(NULL);
		return;
	}
	fprintf(fp, "{\n");
	fprintf(fp, "    \"apiKey\": \"%s\",\n", cloud->api_key);
	fprintf(fp, "    \"apiSecret\": \"%s\",\n", cloud->api_secret);
	fprintf(fp, "    \"apiRegion\": \"%s\",\n", cloud->api_region);
	fprintf(fp, "    \"apiDeviceID\": \"%s\"\n", cloud->api_device_id);
	fprintf(fp, "}\n");
	fclose(fp);
	printf(">> Configuration saved to %s\n", path);
}

static void
save_devices(const char *path, struct tuya_device *devices, int count)
{
	FILE *fp = fopen(path, "w");
	if (!fp) {
		fprintf(stderr, "error: cannot write %s: ", path);
		perror(NULL);
		return;
	}
	fprintf(fp, "[\n");
	for (int i = 0; i < count; i++) {
		struct tuya_device *d = &devices[i];
		fprintf(fp, "    {\n");
		fprintf(fp, "        \"id\": \"%s\",\n", d->id);
		fprintf(fp, "        \"name\": \"%s\",\n", d->name);
		fprintf(fp, "        \"key\": \"%s\",\n", d->key);
		fprintf(fp, "        \"product_id\": \"%s\",\n", d->product_id);
		fprintf(fp, "        \"sub\": %s", d->sub ? "true" : "false");
		if (d->ip[0]) {
			fprintf(fp, ",\n        \"ip\": \"%s\"", d->ip);
			if (d->version[0])
				fprintf(fp, ",\n        \"version\": \"%s\"", d->version);
		}
		fprintf(fp, "\n    }%s\n", (i < count - 1) ? "," : "");
	}
	fprintf(fp, "]\n");
	fclose(fp);
	printf(">> %d device(s) saved to %s\n", count, path);
}

/* ------------------------------------------------------------------ */
/*  User interaction                                                  */
/* ------------------------------------------------------------------ */

static void
prompt_string(const char *msg, char *out, int outsize, const char *dflt)
{
	if (dflt && dflt[0])
		printf("%s [%s]: ", msg, dflt);
	else
		printf("%s: ", msg);
	fflush(stdout);

	char line[512];
	if (!fgets(line, sizeof(line), stdin))
		exit(1);
	char *nl = strchr(line, '\n');
	if (nl) *nl = '\0';

	if (line[0])
		strncpy(out, line, outsize - 1);
	else if (dflt)
		strncpy(out, dflt, outsize - 1);
}

static bool
prompt_yn(const char *msg, bool dflt)
{
	printf("%s [%s]: ", msg, dflt ? "Y/n" : "y/N");
	fflush(stdout);
	char line[16];
	if (!fgets(line, sizeof(line), stdin))
		exit(1);
	if (line[0] == '\n') return dflt;
	return (line[0] == 'y' || line[0] == 'Y');
}

/* ------------------------------------------------------------------ */
/*  Usage                                                             */
/* ------------------------------------------------------------------ */

static void
usage(const char *prog)
{
	fprintf(stderr,
	    "Usage: %s [options]\n"
	    "\n"
	    "Tuya device setup wizard (clone of tinytuya wizard).\n"
	    "Fetches device list and local keys from the Tuya Cloud API,\n"
	    "then scans the local network for device IP addresses.\n"
	    "\n"
	    "Options:\n"
	    "  -k KEY      API Key\n"
	    "  -s SECRET   API Secret\n"
	    "  -r REGION   Region (us, eu, cn, in, sg, us-e, eu-w)\n"
	    "  -i DEVID    Any registered Device ID\n"
	    "  -c FILE     Credentials file  (default: tinytuya.json)\n"
	    "  -o FILE     Device list output (default: devices.json)\n"
	    "  -t SECS     UDP scan timeout   (default: 8)\n"
	    "  -N          No cloud (scan only)\n"
	    "  -y          Assume yes\n"
	    "  -S          Query thing-model shadow properties (v2.0)\n"
	    "  -M          Query thing-model schema (v2.0)\n"
	    "  -I JSON     Issue shadow property set, e.g. '{\"temp_set\":500}'\n",
	    prog);
}

/* ------------------------------------------------------------------ */
/*  Main wizard flow                                                  */
/* ------------------------------------------------------------------ */

int
wizard_main(int argc, char *argv[])
{
	char config_file[512] = "tinytuya.json";
	char device_file[512] = "devices.json";
	int scan_timeout = 8;
	bool no_cloud = false;
	bool assume_yes = false;
	bool shadow_query = false;
	bool model_query = false;
	char issue_json[1024] = "";
	int opt;

	struct tuya_cloud cloud;
	memset(&cloud, 0, sizeof(cloud));

	while ((opt = getopt(argc, argv, "k:s:r:i:c:o:t:NySMI:h")) != -1) {
		switch (opt) {
		case 'k': strncpy(cloud.api_key, optarg, sizeof(cloud.api_key) - 1); break;
		case 's': strncpy(cloud.api_secret, optarg, sizeof(cloud.api_secret) - 1); break;
		case 'r': strncpy(cloud.api_region, optarg, sizeof(cloud.api_region) - 1); break;
		case 'i': strncpy(cloud.api_device_id, optarg, sizeof(cloud.api_device_id) - 1); break;
		case 'c': strncpy(config_file, optarg, sizeof(config_file) - 1); break;
		case 'o': strncpy(device_file, optarg, sizeof(device_file) - 1); break;
		case 't': scan_timeout = atoi(optarg); break;
		case 'N': no_cloud = true; break;
		case 'y': assume_yes = true; break;
		case 'S': shadow_query = true; break;
		case 'M': model_query = true; break;
		case 'I': strncpy(issue_json, optarg, sizeof(issue_json) - 1); break;
		default:
			usage(argv[0]);
			return (opt == 'h') ? 0 : 1;
		}
	}

	printf("seatuya setup wizard [%s]\n\n", tuya_version());

	/* Load saved credentials */
	load_config(config_file, &cloud);

	struct tuya_device *devices = calloc(MAX_DEVICES, sizeof(*devices));
	int device_count = 0;

	if (!no_cloud) {
		bool have_creds = (cloud.api_key[0] && cloud.api_secret[0]
		                   && cloud.api_region[0]);

		if (have_creds && !assume_yes) {
			printf("    Existing settings:\n");
			printf("        API Key    = %s\n", cloud.api_key);
			printf("        API Secret = %s\n", cloud.api_secret);
			printf("        Region     = %s\n", cloud.api_region);
			if (cloud.api_device_id[0])
				printf("        Device ID  = %s\n", cloud.api_device_id);
			printf("\n");
			if (!prompt_yn("    Use existing credentials?", true))
				have_creds = false;
		}

		if (!have_creds) {
			printf("\n");
			prompt_string("    Enter API Key from tuya.com",
			    cloud.api_key, sizeof(cloud.api_key), cloud.api_key);
			prompt_string("    Enter API Secret from tuya.com",
			    cloud.api_secret, sizeof(cloud.api_secret), cloud.api_secret);
			prompt_string("    Enter any Device ID registered in Tuya App",
			    cloud.api_device_id, sizeof(cloud.api_device_id), cloud.api_device_id);

			printf("\n    Region list:\n");
			printf("        cn      China\n");
			printf("        us      US — Western America\n");
			printf("        us-e    US — Eastern America\n");
			printf("        eu      Central Europe\n");
			printf("        eu-w    Western Europe\n");
			printf("        in      India\n");
			printf("        sg      Singapore\n\n");

			prompt_string("    Enter your region",
			    cloud.api_region, sizeof(cloud.api_region), cloud.api_region);
		}

		for (char *p = cloud.api_region; *p; p++)
			*p = tolower(*p);

		save_config(config_file, &cloud);

		cloud.host = region_to_host(cloud.api_region);

		printf("\nConnecting to Tuya Cloud (%s)...\n", cloud.host);
		if (!tuya_get_token(&cloud)) {
			fprintf(stderr, "Authentication failed. Check API Key and Secret.\n");
			free(devices);
			return 1;
		}

		/*
		 * Thing-model one-shot queries.  These are the working
		 * DP access path for devices (e.g. category "mzj") whose
		 * v1.0 status/functions endpoints return empty.
		 */
		if (shadow_query || model_query || issue_json[0]) {
			const char *devid = cloud.api_device_id;
			if (!devid[0]) {
				fprintf(stderr, "-S/-M/-I require a device "
				        "id (-i)\n");
				free(devices);
				return 1;
			}
			char *resp;
			if (model_query) {
				resp = cloud_thing_model(&cloud, devid);
				printf("model:\n%s\n", resp ? resp : "(null)");
				free(resp);
			}
			if (shadow_query) {
				resp = cloud_shadow_properties(&cloud, devid);
				printf("shadow properties:\n%s\n",
				    resp ? resp : "(null)");
				free(resp);
			}
			if (issue_json[0]) {
				resp = cloud_shadow_issue(&cloud, devid,
				           issue_json);
				printf("issue result:\n%s\n",
				    resp ? resp : "(null)");
				free(resp);
			}
			free(devices);
			return 0;
		}
		printf("  authenticated.\n");

		printf("Fetching device list...\n");
		device_count = tuya_get_devices(&cloud, devices, MAX_DEVICES);
		if (device_count < 0) {
			free(devices);
			return 1;
		}

		printf("\nDevice listing (%d devices):\n\n", device_count);
		for (int i = 0; i < device_count; i++) {
			struct tuya_device *d = &devices[i];
			printf("  %-40s id=%-24s key=%s%s\n",
			    d->name, d->id, d->key,
			    d->sub ? "  [sub-device]" : "");
		}

		save_devices(device_file, devices, device_count);
	}

	bool do_scan;
	if (assume_yes)
		do_scan = true;
	else
		do_scan = prompt_yn("\nPoll local devices?", true);

	if (do_scan) {
		device_count = udp_discover(devices, device_count,
		                   MAX_DEVICES, scan_timeout);
		save_devices(device_file, devices, device_count);
	}

	printf("\nDone.\n");
	free(devices);
	return 0;
}
