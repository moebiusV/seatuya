/*
 * wizard-https-libtls.c — HTTPS client using libtls (LibreSSL).
 *
 * Provides https_request() for seatuya-wizard.
 * Linked to produce the seatuya-wizard binary (preferred TLS backend).
 *
 * Copyright (c) 2026, David Walther <david@clearbrookdistillery.com>
 * BSD-2-Clause
 */

#include "wizard-common.h"

#include <stdio.h>
#include <tls.h>

char *
https_request(const char *host, const char *method, const char *path,
              const char **header_keys, const char **header_vals, int nheaders,
              const char *body)
{
	struct tls_config *cfg = tls_config_new();
	if (!cfg) return NULL;

	struct tls *ctx = tls_client();
	if (!ctx) {
		tls_config_free(cfg);
		return NULL;
	}

	tls_configure(ctx, cfg);
	tls_config_free(cfg);

	if (tls_connect(ctx, host, "443") < 0) {
		fprintf(stderr, "error: TLS connection to %s failed: %s\n",
		        host, tls_error(ctx));
		tls_free(ctx);
		return NULL;
	}

	if (tls_handshake(ctx) < 0) {
		fprintf(stderr, "error: TLS handshake with %s failed: %s\n",
		        host, tls_error(ctx));
		tls_free(ctx);
		return NULL;
	}

	struct strbuf req;
	strbuf_init(&req);
	build_http_request(&req, host, method, path,
	                   header_keys, header_vals, nheaders, body);

	ssize_t off = 0;
	while (off < (ssize_t)req.len) {
		ssize_t w = tls_write(ctx, req.data + off, req.len - off);
		if (w == TLS_WANT_POLLIN || w == TLS_WANT_POLLOUT)
			continue;
		if (w < 0) {
			fprintf(stderr, "error: tls_write: %s\n", tls_error(ctx));
			strbuf_free(&req);
			tls_free(ctx);
			return NULL;
		}
		off += w;
	}
	strbuf_free(&req);

	struct strbuf resp;
	strbuf_init(&resp);
	char buf[4096];
	for (;;) {
		ssize_t rd = tls_read(ctx, buf, sizeof(buf));
		if (rd == TLS_WANT_POLLIN || rd == TLS_WANT_POLLOUT)
			continue;
		if (rd <= 0) break;
		strbuf_append(&resp, buf, rd);
	}

	tls_close(ctx);
	tls_free(ctx);

	char *result = extract_json_body(&resp);
	strbuf_free(&resp);
	return result;
}

int
main(int argc, char *argv[])
{
	return wizard_main(argc, argv);
}
