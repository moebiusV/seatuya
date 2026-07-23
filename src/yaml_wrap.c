/* yaml_wrap.c — Minimal libyaml wrapper for newLISP FFI
 *
 * Exposes yaml_parse_file(path) → malloc'd S-expression string.
 * Links libyaml-0.so.2 (already installed on the system).
 *
 * The returned string is malloc'd — caller (newLISP yaml.lsp) frees it.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <yaml.h>

/* Forward-declare the recursive emitter */
static void emit_event(yaml_event_t *e, const char **pending_key);

static int out_len = 0, out_cap = 0;
static char *out = NULL;

static void out_putc(char c) {
    if (out_len + 1 >= out_cap) {
        out_cap = out_cap ? out_cap * 2 : 4096;
        out = realloc(out, out_cap);
    }
    out[out_len++] = c;
}

static void out_str(const char *s) {
    if (!s) return;
    size_t n = strlen(s);
    if (out_len + n + 1 >= out_cap) {
        out_cap = out_cap ? out_cap * 2 : 4096;
        while (out_len + n + 1 >= out_cap) out_cap *= 2;
        out = realloc(out, out_cap);
    }
    memcpy(out + out_len, s, n);
    out_len += n;
}

static void emit_scalar(const char *s) {
    if (!s) { out_str("nil"); return; }
    if (!strcmp(s, "true") || !strcmp(s, "True") || !strcmp(s, "TRUE"))
    { out_str("true"); return; }
    if (!strcmp(s, "false") || !strcmp(s, "False") || !strcmp(s, "FALSE"))
    { out_str("nil"); return; }
    if (!strcmp(s, "null") || !strcmp(s, "Null") || !strcmp(s, "NULL")
        || !strcmp(s, "~"))
    { out_str("nil"); return; }
    char *end;
    long v = strtol(s, &end, 10);
    if (*end == '\0' && end != s) { char b[32]; snprintf(b, 32, "%ld", v); out_str(b); return; }
    double d = strtod(s, &end);
    if (*end == '\0' && end != s) { char b[32]; snprintf(b, 32, "%g", d); out_str(b); return; }
    int quote = 0;
    for (const char *p = s; *p && !quote; p++)
        if (*p == ' ' || *p == '(' || *p == ')' || *p == '"' || *p == '\'') quote = 1;
    if (quote) { out_putc('"'); out_str(s); out_putc('"'); }
    else out_str(s);
}

static int process_file(FILE *f) {
    yaml_parser_t parser;
    yaml_event_t event;
    int done = 0, depth = 0;
    const char *pending_key = NULL;

    yaml_parser_initialize(&parser);
    yaml_parser_set_input_file(&parser, f);

    while (!done) {
        if (!yaml_parser_parse(&parser, &event)) {
            yaml_parser_delete(&parser);
            return 0;
        }
        switch (event.type) {
        case YAML_STREAM_START_EVENT: break;
        case YAML_DOCUMENT_START_EVENT: break;
        case YAML_STREAM_END_EVENT: done = 1; break;
        case YAML_DOCUMENT_END_EVENT: break;
        case YAML_SEQUENCE_START_EVENT: out_str("("); depth++; break;
        case YAML_SEQUENCE_END_EVENT: depth--; out_str(")"); break;
        case YAML_MAPPING_START_EVENT: out_str("("); depth++; break;
        case YAML_MAPPING_END_EVENT: depth--; out_str(")"); break;
        case YAML_SCALAR_EVENT:
            if (pending_key) {
                out_str("(\"");
                out_str(pending_key);
                out_str("\" ");
                emit_scalar((const char *)event.data.scalar.value);
                out_str(")");
                pending_key = NULL;
            } else {
                pending_key = (const char *)event.data.scalar.value;
            }
            break;
        default: break;
        }
        yaml_event_delete(&event);
    }
    yaml_parser_delete(&parser);
    return 1;
}

/* Public API for newLISP FFI */

char *yaml_parse_file(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) return NULL;
    out_len = 0;
    out_str("(");
    if (!process_file(f)) {
        fclose(f);
        free(out); out = NULL;
        return NULL;
    }
    out_str(")");
    out_putc('\0');
    fclose(f);
    return out;  /* caller frees with free() */
}

char *yaml_parse_string(const char *str) {
    out_len = 0;
    out_str("(");
    yaml_parser_t parser;
    yaml_event_t event;
    int done = 0;
    const char *pending_key = NULL;

    yaml_parser_initialize(&parser);
    yaml_parser_set_input_string(&parser, (const unsigned char *)str, strlen(str));

    while (!done) {
        if (!yaml_parser_parse(&parser, &event)) {
            yaml_parser_delete(&parser);
            free(out); out = NULL;
            return NULL;
        }
        switch (event.type) {
        case YAML_STREAM_START_EVENT: break;
        case YAML_DOCUMENT_START_EVENT: break;
        case YAML_STREAM_END_EVENT: done = 1; break;
        case YAML_DOCUMENT_END_EVENT: break;
        case YAML_SEQUENCE_START_EVENT: out_str("("); break;
        case YAML_SEQUENCE_END_EVENT: out_str(")"); break;
        case YAML_MAPPING_START_EVENT: out_str("("); break;
        case YAML_MAPPING_END_EVENT: out_str(")"); break;
        case YAML_SCALAR_EVENT:
            if (pending_key) {
                out_str("(\"");
                out_str(pending_key);
                out_str("\" ");
                emit_scalar((const char *)event.data.scalar.value);
                out_str(")");
                pending_key = NULL;
            } else {
                pending_key = (const char *)event.data.scalar.value;
            }
            break;
        default: break;
        }
        yaml_event_delete(&event);
    }
    yaml_parser_delete(&parser);
    out_str(")");
    out_putc('\0');
    return out;
}
