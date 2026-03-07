/*
 * wizard-common.h — Shared declarations for seatuya-wizard.
 *
 * Copyright (c) 2026, David Walther <david@clearbrookdistillery.com>
 * BSD-2-Clause
 */

#ifndef WIZARD_COMMON_H
#define WIZARD_COMMON_H

#include <stdbool.h>
#include <stddef.h>

/* ------------------------------------------------------------------ */
/*  Limits                                                            */
/* ------------------------------------------------------------------ */

enum { MAX_DEVICES    = 256 };
enum { MAX_BUF        = 4096 };
enum { MAX_RESPONSE   = 65536 };
enum { UDP_PORT       = 6666 };

/* ------------------------------------------------------------------ */
/*  Simple growable string buffer                                     */
/* ------------------------------------------------------------------ */

struct strbuf {
	char  *data;
	size_t len;
	size_t cap;
};

void strbuf_init(struct strbuf *sb);
void strbuf_append(struct strbuf *sb, const char *s, size_t n);
void strbuf_free(struct strbuf *sb);

/* ------------------------------------------------------------------ */
/*  HTTP helpers (used by TLS backends)                               */
/* ------------------------------------------------------------------ */

void build_http_request(struct strbuf *req, const char *host,
                        const char *method, const char *path,
                        const char **header_keys,
                        const char **header_vals, int nheaders,
                        const char *body);

char *extract_json_body(struct strbuf *resp);

/* ------------------------------------------------------------------ */
/*  HTTPS client — provided by the TLS backend                       */
/* ------------------------------------------------------------------ */

char *https_request(const char *host, const char *method, const char *path,
                    const char **header_keys, const char **header_vals,
                    int nheaders, const char *body);

/* ------------------------------------------------------------------ */
/*  Wizard main entry point                                          */
/* ------------------------------------------------------------------ */

int wizard_main(int argc, char *argv[]);

#endif /* WIZARD_COMMON_H */
