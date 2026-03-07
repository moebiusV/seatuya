/*
 * wizard-https-openssl.c — HTTPS client using OpenSSL BIO.
 *
 * Provides https_request() for seatuya-wizard.
 * Linked to produce the seatuya-wizard-openssl binary (fallback TLS backend).
 *
 * Copyright (c) 2026, David Walther <david@clearbrookdistillery.com>
 * BSD-2-Clause
 */

#include "wizard-common.h"

#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/ssl.h>
#include <stdio.h>

char *
https_request(const char *host, const char *method, const char *path,
              const char **header_keys, const char **header_vals, int nheaders,
              const char *body)
{
	SSL_CTX *ctx = SSL_CTX_new(TLS_client_method());
	if (!ctx) return NULL;

	BIO *bio = BIO_new_ssl_connect(ctx);
	if (!bio) {
		SSL_CTX_free(ctx);
		return NULL;
	}

	char hostport[512];
	snprintf(hostport, sizeof(hostport), "%s:443", host);
	BIO_set_conn_hostname(bio, hostport);

	SSL *ssl = NULL;
	BIO_get_ssl(bio, &ssl);
	if (ssl)
		SSL_set_tlsext_host_name(ssl, host);

	if (BIO_do_connect(bio) <= 0) {
		fprintf(stderr, "error: TLS connection to %s failed\n", host);
		BIO_free_all(bio);
		SSL_CTX_free(ctx);
		return NULL;
	}

	struct strbuf req;
	strbuf_init(&req);
	build_http_request(&req, host, method, path,
	                   header_keys, header_vals, nheaders, body);

	BIO_write(bio, req.data, req.len);
	strbuf_free(&req);

	struct strbuf resp;
	strbuf_init(&resp);
	char buf[4096];
	int rd;
	while ((rd = BIO_read(bio, buf, sizeof(buf))) > 0)
		strbuf_append(&resp, buf, rd);

	BIO_free_all(bio);
	SSL_CTX_free(ctx);

	char *result = extract_json_body(&resp);
	strbuf_free(&resp);
	return result;
}

int
main(int argc, char *argv[])
{
	return wizard_main(argc, argv);
}
