/*
 * seatuya_nif.c -- Erlang NIF wrapper for libseatuya
 *
 * Compile:
 *   cc -fPIC -shared -I$ERLANG_ROOT/usr/include \
 *       -I/usr/local/include -L/usr/local/lib \
 *       -o seatuya_nif.so seatuya_nif.c -lseatuya
 *
 * Set SEATUYA_LIB env var to override the NIF .so path at runtime.
 */

#include <erl_nif.h>
#include <string.h>
#include <stdlib.h>

#include "seatuya.h"

/* ------------------------------------------------------------------ */
/*  Resource type for tuya_device_t *                                  */
/* ------------------------------------------------------------------ */

static ErlNifResourceType *dev_res_type = NULL;

typedef struct {
    tuya_device_t *dev;
} dev_res_t;

static void dev_dtor(ErlNifEnv *env, void *obj) {
    dev_res_t *r = (dev_res_t *)obj;
    if (r->dev) {
        tuya_destroy(r->dev);
        r->dev = NULL;
    }
}

/* ------------------------------------------------------------------ */
/*  Atoms                                                              */
/* ------------------------------------------------------------------ */

static ERL_NIF_TERM A_OK;
static ERL_NIF_TERM A_ERROR;
static ERL_NIF_TERM A_TRUE;
static ERL_NIF_TERM A_FALSE;
static ERL_NIF_TERM A_NIL;

/* ------------------------------------------------------------------ */
/*  Helpers                                                            */
/* ------------------------------------------------------------------ */

static int load_atoms(ErlNifEnv *env) {
    A_OK    = enif_make_atom(env, "ok");
    A_ERROR = enif_make_atom(env, "error");
    A_TRUE  = enif_make_atom(env, "true");
    A_FALSE = enif_make_atom(env, "false");
    A_NIL   = enif_make_atom(env, "nil");
    return 0;
}

static tuya_device_t *get_dev(ErlNifEnv *env, ERL_NIF_TERM t) {
    dev_res_t *r;
    if (!enif_get_resource(env, t, dev_res_type, (void **)&r))
        return NULL;
    return r->dev;
}

static ERL_NIF_TERM make_dev(ErlNifEnv *env, tuya_device_t *dev) {
    if (!dev) return A_NIL;
    dev_res_t *r = enif_alloc_resource(dev_res_type, sizeof(dev_res_t));
    if (!r) { tuya_destroy(dev); return A_NIL; }
    r->dev = dev;
    ERL_NIF_TERM term = enif_make_resource(env, r);
    enif_release_resource(r);
    return term;
}

/* Convert a malloc'd C string into an Erlang string and free it. */
static ERL_NIF_TERM take_string(ErlNifEnv *env, char *cstr) {
    if (!cstr) return A_NIL;
    ERL_NIF_TERM s = enif_make_string(env, cstr, ERL_NIF_LATIN1);
    tuya_free_string(cstr);
    return s;
}

static ERL_NIF_TERM bool_to_term(ErlNifEnv *env, bool v) {
    return v ? A_TRUE : A_FALSE;
}

/* ------------------------------------------------------------------ */
/*  NIFs                                                               */
/* ------------------------------------------------------------------ */

/* tuya_version() -> string */
static ERL_NIF_TERM nif_version(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
    return enif_make_string(env, tuya_version(), ERL_NIF_LATIN1);
}

/* tuya_create(dev_id, addr, key, ver) -> {ok, Ref} | {error, Reason} */
static ERL_NIF_TERM nif_create(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {
    char d[256], a[256], k[256], v[32];
    if (enif_get_string(env, argv[0], d, sizeof d, ERL_NIF_LATIN1) <= 0 ||
        enif_get_string(env, argv[1], a, sizeof a, ERL_NIF_LATIN1) <= 0 ||
        enif_get_string(env, argv[2], k, sizeof k, ERL_NIF_LATIN1) <= 0 ||
        enif_get_string(env, argv[3], v, sizeof v, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    tuya_device_t *dev = tuya_create(d, a, k, v);
    if (!dev)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "create_failed"));
    return enif_make_tuple2(env, A_OK, make_dev(env, dev));
}

/* tuya_alloc(ver) -> {ok, Ref} | {error, Reason} */
static ERL_NIF_TERM nif_alloc(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]) {
    char v[32];
    if (enif_get_string(env, argv[0], v, sizeof v, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    tuya_device_t *dev = tuya_alloc(v);
    if (!dev)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "alloc_failed"));
    return enif_make_tuple2(env, A_OK, make_dev(env, dev));
}

/* tuya_destroy(Ref) -> ok */
static ERL_NIF_TERM nif_destroy(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return A_OK;
    dev_res_t *r;
    if (enif_get_resource(env, argv[0], dev_res_type, (void **)&r)) {
        r->dev = NULL;
    }
    tuya_destroy(dev);
    return A_OK;
}

/* tuya_set_credentials(Ref, dev_id, key) -> ok */
static ERL_NIF_TERM nif_set_credentials(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    char d[256], k[256];
    if (!dev ||
        enif_get_string(env, argv[1], d, sizeof d, ERL_NIF_LATIN1) <= 0 ||
        enif_get_string(env, argv[2], k, sizeof k, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    tuya_set_credentials(dev, d, k);
    return A_OK;
}

/* tuya_get_device_id(Ref) -> string */
static ERL_NIF_TERM nif_get_device_id(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    const char *s = tuya_get_device_id(dev);
    return enif_make_string(env, s ? s : "", ERL_NIF_LATIN1);
}

/* tuya_get_local_key(Ref) -> string */
static ERL_NIF_TERM nif_get_local_key(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    const char *s = tuya_get_local_key(dev);
    return enif_make_string(env, s ? s : "", ERL_NIF_LATIN1);
}

/* tuya_get_ip(Ref) -> string */
static ERL_NIF_TERM nif_get_ip(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    const char *s = tuya_get_ip(dev);
    return enif_make_string(env, s ? s : "", ERL_NIF_LATIN1);
}

/* tuya_connect(Ref, hostname) -> true | false */
static ERL_NIF_TERM nif_connect(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    char h[256];
    if (!dev ||
        enif_get_string(env, argv[1], h, sizeof h, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    return bool_to_term(env, tuya_connect(dev, h));
}

/* tuya_disconnect(Ref) -> ok */
static ERL_NIF_TERM nif_disconnect(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    tuya_disconnect(dev);
    return A_OK;
}

/* tuya_is_connected(Ref) -> true | false */
static ERL_NIF_TERM nif_is_connected(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return bool_to_term(env, tuya_is_connected(dev));
}

/* tuya_reconnect(Ref) -> true | false */
static ERL_NIF_TERM nif_reconnect(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return bool_to_term(env, tuya_reconnect(dev));
}

/* tuya_set_retry_limit(Ref, limit) -> ok */
static ERL_NIF_TERM nif_set_retry_limit(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int lim;
    if (!dev || !enif_get_int(env, argv[1], &lim))
        return enif_make_badarg(env);
    tuya_set_retry_limit(dev, lim);
    return A_OK;
}

/* tuya_set_retry_delay(Ref, ms) -> ok */
static ERL_NIF_TERM nif_set_retry_delay(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int ms;
    if (!dev || !enif_get_int(env, argv[1], &ms))
        return enif_make_badarg(env);
    tuya_set_retry_delay(dev, ms);
    return A_OK;
}

/* tuya_get_retry_limit(Ref) -> int */
static ERL_NIF_TERM nif_get_retry_limit(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return enif_make_int(env, tuya_get_retry_limit(dev));
}

/* tuya_get_retry_delay(Ref) -> int */
static ERL_NIF_TERM nif_get_retry_delay(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return enif_make_int(env, tuya_get_retry_delay(dev));
}

/* tuya_negotiate_session(Ref, key) -> true | false */
static ERL_NIF_TERM nif_negotiate_session(ErlNifEnv *env, int argc,
                                           const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    char k[256];
    if (!dev ||
        enif_get_string(env, argv[1], k, sizeof k, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    return bool_to_term(env, tuya_negotiate_session(dev, k));
}

/* tuya_negotiate_session_start(Ref, key) -> true | false */
static ERL_NIF_TERM nif_negotiate_session_start(ErlNifEnv *env, int argc,
                                                 const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    char k[256];
    if (!dev ||
        enif_get_string(env, argv[1], k, sizeof k, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    return bool_to_term(env, tuya_negotiate_session_start(dev, k));
}

/* tuya_negotiate_session_finalize(Ref, Bin, key) -> true | false */
static ERL_NIF_TERM nif_negotiate_session_finalize(ErlNifEnv *env, int argc,
                                                    const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    ErlNifBinary bin;
    char k[256];
    if (!dev ||
        !enif_inspect_binary(env, argv[1], &bin) ||
        enif_get_string(env, argv[2], k, sizeof k, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    return bool_to_term(env, tuya_negotiate_session_finalize(
        dev, bin.data, (int)bin.size, k));
}

/* tuya_get_protocol(Ref) -> int */
static ERL_NIF_TERM nif_get_protocol(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return enif_make_int(env, (int)tuya_get_protocol(dev));
}

/* tuya_get_session_state(Ref) -> int */
static ERL_NIF_TERM nif_get_session_state(ErlNifEnv *env, int argc,
                                           const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return enif_make_int(env, (int)tuya_get_session_state(dev));
}

/* tuya_get_socket_state(Ref) -> int */
static ERL_NIF_TERM nif_get_socket_state(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return enif_make_int(env, (int)tuya_get_socket_state(dev));
}

/* tuya_get_last_error(Ref) -> int */
static ERL_NIF_TERM nif_get_last_error(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return enif_make_int(env, tuya_get_last_error(dev));
}

/* tuya_set_async_mode(Ref, Bool) -> ok */
static ERL_NIF_TERM nif_set_async_mode(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    tuya_set_async_mode(dev, argv[1] == A_TRUE);
    return A_OK;
}

/* tuya_is_socket_readable(Ref) -> true | false */
static ERL_NIF_TERM nif_is_socket_readable(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return bool_to_term(env, tuya_is_socket_readable(dev));
}

/* tuya_is_socket_writable(Ref) -> true | false */
static ERL_NIF_TERM nif_is_socket_writable(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return bool_to_term(env, tuya_is_socket_writable(dev));
}

/* tuya_set_session_ready(Ref) -> true | false */
static ERL_NIF_TERM nif_set_session_ready(ErlNifEnv *env, int argc,
                                           const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return bool_to_term(env, tuya_set_session_ready(dev));
}

/* tuya_build_message(Ref, Bin, Cmd, Payload, Key) -> {ok, Bin, Size} | {error, Reason} */
static ERL_NIF_TERM nif_build_message(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int cmd;
    ErlNifBinary bin;
    char payload[4096], key[256];
    if (!dev ||
        !enif_inspect_binary(env, argv[1], &bin) ||
        !enif_get_int(env, argv[2], &cmd) ||
        enif_get_string(env, argv[3], payload, sizeof payload, ERL_NIF_LATIN1) <= 0 ||
        enif_get_string(env, argv[4], key, sizeof key, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    int sz = tuya_build_message(dev, bin.data, (enum tuya_command)cmd,
                                 payload, key);
    if (sz < 0)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "build_failed"));
    return enif_make_tuple3(env, A_OK, argv[1], enif_make_int(env, sz));
}

/* tuya_decode_message(Ref, Bin, Key) -> {ok, String} | {error, Reason} */
static ERL_NIF_TERM nif_decode_message(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    ErlNifBinary bin;
    char key[256];
    if (!dev ||
        !enif_inspect_binary(env, argv[1], &bin) ||
        enif_get_string(env, argv[2], key, sizeof key, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    char *result = tuya_decode_message(dev, bin.data, (int)bin.size, key);
    if (!result)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "decode_failed"));
    ERL_NIF_TERM s = enif_make_string(env, result, ERL_NIF_LATIN1);
    tuya_free_string(result);
    return enif_make_tuple2(env, A_OK, s);
}

/* tuya_generate_payload(Ref, Cmd, DevId, Dps) -> {ok, String} | {error, Reason} */
static ERL_NIF_TERM nif_generate_payload(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int cmd;
    char dev_id[256], dps[4096];
    if (!dev ||
        !enif_get_int(env, argv[1], &cmd) ||
        enif_get_string(env, argv[2], dev_id, sizeof dev_id, ERL_NIF_LATIN1) <= 0 ||
        enif_get_string(env, argv[3], dps, sizeof dps, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    char *result = tuya_generate_payload(dev, (enum tuya_command)cmd,
                                          dev_id, dps);
    if (!result)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "generate_failed"));
    ERL_NIF_TERM s = enif_make_string(env, result, ERL_NIF_LATIN1);
    tuya_free_string(result);
    return enif_make_tuple2(env, A_OK, s);
}

/* tuya_send(Ref, Bin) -> {ok, Sent} | {error, Reason} */
static ERL_NIF_TERM nif_send(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    ErlNifBinary bin;
    if (!dev || !enif_inspect_binary(env, argv[1], &bin))
        return enif_make_badarg(env);
    int sent = tuya_send(dev, bin.data, (int)bin.size);
    if (sent < 0)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "send_failed"));
    return enif_make_tuple2(env, A_OK, enif_make_int(env, sent));
}

/* tuya_receive(Ref, MaxSize, MinSize) -> {ok, Bin} | {error, Reason} */
static ERL_NIF_TERM nif_receive(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int maxsize, minsize;
    if (!dev ||
        !enif_get_int(env, argv[1], &maxsize) ||
        !enif_get_int(env, argv[2], &minsize))
        return enif_make_badarg(env);
    ERL_NIF_TERM bin_term;
    unsigned char *buf = enif_make_new_binary(env, (size_t)maxsize, &bin_term);
    if (!buf)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "alloc_failed"));
    int got = tuya_receive(dev, buf, maxsize, minsize);
    if (got < 0)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "receive_failed"));
    if (got < maxsize)
        enif_resize_binary(env, bin_term, (size_t)got);
    return enif_make_tuple2(env, A_OK, bin_term);
}

/* tuya_set_device22(Ref, NullDpsJson) -> ok */
static ERL_NIF_TERM nif_set_device22(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    char json[4096];
    if (!dev ||
        enif_get_string(env, argv[1], json, sizeof json, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    tuya_set_device22(dev, json);
    return A_OK;
}

/* tuya_is_device22(Ref) -> true | false */
static ERL_NIF_TERM nif_is_device22(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    return bool_to_term(env, tuya_is_device22(dev));
}

/* tuya_set_value_bool(Ref, Dp, Bool) -> {ok, String} | {error, Reason} */
static ERL_NIF_TERM nif_set_value_bool(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int dp;
    if (!dev || !enif_get_int(env, argv[1], &dp))
        return enif_make_badarg(env);
    bool v = (argv[2] == A_TRUE);
    char *result = tuya_set_value_bool(dev, dp, v);
    if (!result)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "set_value_failed"));
    ERL_NIF_TERM s = enif_make_string(env, result, ERL_NIF_LATIN1);
    tuya_free_string(result);
    return enif_make_tuple2(env, A_OK, s);
}

/* tuya_set_value_int(Ref, Dp, Int) -> {ok, String} | {error, Reason} */
static ERL_NIF_TERM nif_set_value_int(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int dp, val;
    if (!dev || !enif_get_int(env, argv[1], &dp) ||
        !enif_get_int(env, argv[2], &val))
        return enif_make_badarg(env);
    char *result = tuya_set_value_int(dev, dp, val);
    if (!result)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "set_value_failed"));
    ERL_NIF_TERM s = enif_make_string(env, result, ERL_NIF_LATIN1);
    tuya_free_string(result);
    return enif_make_tuple2(env, A_OK, s);
}

/* tuya_set_value_string(Ref, Dp, String) -> {ok, String} | {error, Reason} */
static ERL_NIF_TERM nif_set_value_string(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int dp;
    char val[4096];
    if (!dev || !enif_get_int(env, argv[1], &dp) ||
        enif_get_string(env, argv[2], val, sizeof val, ERL_NIF_LATIN1) <= 0)
        return enif_make_badarg(env);
    char *result = tuya_set_value_string(dev, dp, val);
    if (!result)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "set_value_failed"));
    ERL_NIF_TERM s = enif_make_string(env, result, ERL_NIF_LATIN1);
    tuya_free_string(result);
    return enif_make_tuple2(env, A_OK, s);
}

/* tuya_set_value_float(Ref, Dp, Float) -> {ok, String} | {error, Reason} */
static ERL_NIF_TERM nif_set_value_float(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int dp;
    double val;
    if (!dev || !enif_get_int(env, argv[1], &dp) ||
        !enif_get_double(env, argv[2], &val))
        return enif_make_badarg(env);
    char *result = tuya_set_value_float(dev, dp, val);
    if (!result)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "set_value_failed"));
    ERL_NIF_TERM s = enif_make_string(env, result, ERL_NIF_LATIN1);
    tuya_free_string(result);
    return enif_make_tuple2(env, A_OK, s);
}

/* tuya_turn_on(Ref, SwitchDp) -> {ok, String} | {error, Reason} */
static ERL_NIF_TERM nif_turn_on(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int dp;
    if (!dev || !enif_get_int(env, argv[1], &dp))
        return enif_make_badarg(env);
    char *result = tuya_turn_on(dev, dp);
    if (!result)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "turn_on_failed"));
    ERL_NIF_TERM s = enif_make_string(env, result, ERL_NIF_LATIN1);
    tuya_free_string(result);
    return enif_make_tuple2(env, A_OK, s);
}

/* tuya_turn_off(Ref, SwitchDp) -> {ok, String} | {error, Reason} */
static ERL_NIF_TERM nif_turn_off(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    int dp;
    if (!dev || !enif_get_int(env, argv[1], &dp))
        return enif_make_badarg(env);
    char *result = tuya_turn_off(dev, dp);
    if (!result)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "turn_off_failed"));
    ERL_NIF_TERM s = enif_make_string(env, result, ERL_NIF_LATIN1);
    tuya_free_string(result);
    return enif_make_tuple2(env, A_OK, s);
}

/* tuya_status(Ref) -> {ok, String} | {error, Reason} */
static ERL_NIF_TERM nif_status(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    char *result = tuya_status(dev);
    if (!result)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "status_failed"));
    ERL_NIF_TERM s = enif_make_string(env, result, ERL_NIF_LATIN1);
    tuya_free_string(result);
    return enif_make_tuple2(env, A_OK, s);
}

/* tuya_heartbeat(Ref) -> {ok, String} | {error, Reason} */
static ERL_NIF_TERM nif_heartbeat(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]) {
    tuya_device_t *dev = get_dev(env, argv[0]);
    if (!dev) return enif_make_badarg(env);
    char *result = tuya_heartbeat(dev);
    if (!result)
        return enif_make_tuple2(env, A_ERROR,
                                enif_make_atom(env, "heartbeat_failed"));
    ERL_NIF_TERM s = enif_make_string(env, result, ERL_NIF_LATIN1);
    tuya_free_string(result);
    return enif_make_tuple2(env, A_OK, s);
}

/* tuya_free_string(String) -> ok */
static ERL_NIF_TERM nif_free_string(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
    /* Erlang strings are managed by the VM -- this is provided */
    /* for direct NIF-level use only. */
    return A_OK;
}

/* ------------------------------------------------------------------ */
/*  NIF table                                                          */
/* ------------------------------------------------------------------ */

static ErlNifFunc nif_funcs[] = {
    {"version",                0, nif_version},
    {"create",                 4, nif_create},
    {"alloc",                  1, nif_alloc},
    {"destroy",                1, nif_destroy},
    {"set_credentials",        3, nif_set_credentials},
    {"get_device_id",          1, nif_get_device_id},
    {"get_local_key",          1, nif_get_local_key},
    {"get_ip",                 1, nif_get_ip},
    {"connect",                2, nif_connect},
    {"disconnect",             1, nif_disconnect},
    {"is_connected",           1, nif_is_connected},
    {"reconnect",              1, nif_reconnect},
    {"set_retry_limit",        2, nif_set_retry_limit},
    {"set_retry_delay",        2, nif_set_retry_delay},
    {"get_retry_limit",        1, nif_get_retry_limit},
    {"get_retry_delay",        1, nif_get_retry_delay},
    {"negotiate_session",      2, nif_negotiate_session},
    {"negotiate_session_start",2, nif_negotiate_session_start},
    {"negotiate_session_finalize",3, nif_negotiate_session_finalize},
    {"get_protocol",           1, nif_get_protocol},
    {"get_session_state",      1, nif_get_session_state},
    {"get_socket_state",       1, nif_get_socket_state},
    {"get_last_error",         1, nif_get_last_error},
    {"set_async_mode",         2, nif_set_async_mode},
    {"is_socket_readable",     1, nif_is_socket_readable},
    {"is_socket_writable",     1, nif_is_socket_writable},
    {"set_session_ready",      1, nif_set_session_ready},
    {"build_message",          5, nif_build_message},
    {"decode_message",         3, nif_decode_message},
    {"generate_payload",       4, nif_generate_payload},
    {"send",                   2, nif_send},
    {"receive",                3, nif_receive},
    {"set_device22",           2, nif_set_device22},
    {"is_device22",            1, nif_is_device22},
    {"set_value_bool",         3, nif_set_value_bool},
    {"set_value_int",          3, nif_set_value_int},
    {"set_value_string",       3, nif_set_value_string},
    {"set_value_float",        3, nif_set_value_float},
    {"turn_on",                2, nif_turn_on},
    {"turn_off",               2, nif_turn_off},
    {"status",                 1, nif_status},
    {"heartbeat",              1, nif_heartbeat},
    {"free_string",            1, nif_free_string}
};

/* ------------------------------------------------------------------ */
/*  NIF init                                                           */
/* ------------------------------------------------------------------ */

static int on_load(ErlNifEnv *env, void **priv, ERL_NIF_TERM info) {
    ErlNifResourceFlags flags = ERL_NIF_RT_CREATE;
    dev_res_type = enif_open_resource_type(env, NULL, "tuya_device_t",
                                            &dev_dtor, flags, NULL);
    if (!dev_res_type) return -1;
    load_atoms(env);
    return 0;
}

ERL_NIF_INIT(seatuya, nif_funcs, &on_load, NULL, NULL, NULL)
