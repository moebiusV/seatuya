/*
 * seatuya_r.c -- R .Call wrappers for libseatuya
 *
 * Compile:
 *   R CMD SHLIB -o seatuya_r.so seatuya_r.c -lseatuya
 *
 * Or use the Makevars approach within an R package skeleton.
 */

#include <R.h>
#include <Rinternals.h>
#include <string.h>
#include <stdlib.h>

#include "seatuya.h"

/* ------------------------------------------------------------------ */
/*  Finalizer for external pointer (auto-destroy on GC)                */
/* ------------------------------------------------------------------ */

static void device_finalizer(SEXP ptr) {
    if (R_ExternalPtrAddr(ptr) == NULL) return;
    tuya_device_t *dev = (tuya_device_t *)R_ExternalPtrAddr(ptr);
    R_ClearExternalPtr(ptr);
    tuya_destroy(dev);
}

/* ------------------------------------------------------------------ */
/*  Helper: create an external pointer wrapping a tuya_device_t *      */
/* ------------------------------------------------------------------ */

static SEXP make_device_ptr(tuya_device_t *dev) {
    if (dev == NULL) return R_NilValue;
    SEXP ptr = PROTECT(R_MakeExternalPtr(dev, R_NilValue, R_NilValue));
    R_RegisterCFinalizer(ptr, device_finalizer);
    SET_CLASS(ptr, Rf_mkString("TuyaDevice"));
    UNPROTECT(1);
    return ptr;
}

static tuya_device_t *get_device(SEXP ptr) {
    if (TYPEOF(ptr) != EXTPTRSXP) error("expected an external pointer");
    tuya_device_t *dev = (tuya_device_t *)R_ExternalPtrAddr(ptr);
    if (dev == NULL) error("device pointer is NULL (already destroyed?)");
    return dev;
}

/* ------------------------------------------------------------------ */
/*  Helper: take a malloc'd C string, wrap as R string, free the C one */
/* ------------------------------------------------------------------ */

static SEXP take_string(char *cstr) {
    if (cstr == NULL) return R_NilValue;
    SEXP s = PROTECT(Rf_ScalarString(Rf_mkChar(cstr)));
    tuya_free_string(cstr);
    UNPROTECT(1);
    return s;
}

/* ---- .Call wrappers ---------------------------------------------- */

SEXP R_tuya_version(void) {
    return Rf_ScalarString(Rf_mkChar(tuya_version()));
}

SEXP R_tuya_create(SEXP dev_id, SEXP addr, SEXP key, SEXP ver) {
    const char *c_dev_id = CHAR(STRING_ELT(dev_id, 0));
    const char *c_addr   = CHAR(STRING_ELT(addr, 0));
    const char *c_key    = CHAR(STRING_ELT(key, 0));
    const char *c_ver    = CHAR(STRING_ELT(ver, 0));
    return make_device_ptr(tuya_create(c_dev_id, c_addr, c_key, c_ver));
}

SEXP R_tuya_alloc(SEXP ver) {
    return make_device_ptr(tuya_alloc(CHAR(STRING_ELT(ver, 0))));
}

SEXP R_tuya_destroy(SEXP dev_sexp) {
    tuya_device_t *dev = get_device(dev_sexp);
    R_ClearExternalPtr(dev_sexp);
    tuya_destroy(dev);
    return R_NilValue;
}

SEXP R_tuya_set_credentials(SEXP dev_sexp, SEXP device_id, SEXP local_key) {
    tuya_device_t *dev = get_device(dev_sexp);
    tuya_set_credentials(dev, CHAR(STRING_ELT(device_id, 0)),
                               CHAR(STRING_ELT(local_key, 0)));
    return R_NilValue;
}

SEXP R_tuya_get_device_id(SEXP dev_sexp) {
    const char *s = tuya_get_device_id(get_device(dev_sexp));
    return Rf_ScalarString(Rf_mkChar(s ? s : ""));
}

SEXP R_tuya_get_local_key(SEXP dev_sexp) {
    const char *s = tuya_get_local_key(get_device(dev_sexp));
    return Rf_ScalarString(Rf_mkChar(s ? s : ""));
}

SEXP R_tuya_get_ip(SEXP dev_sexp) {
    const char *s = tuya_get_ip(get_device(dev_sexp));
    return Rf_ScalarString(Rf_mkChar(s ? s : ""));
}

SEXP R_tuya_connect(SEXP dev_sexp, SEXP hostname) {
    bool ok = tuya_connect(get_device(dev_sexp),
                           CHAR(STRING_ELT(hostname, 0)));
    return Rf_ScalarLogical(ok ? TRUE : FALSE);
}

SEXP R_tuya_disconnect(SEXP dev_sexp) {
    tuya_disconnect(get_device(dev_sexp));
    return R_NilValue;
}

SEXP R_tuya_is_connected(SEXP dev_sexp) {
    return Rf_ScalarLogical(tuya_is_connected(get_device(dev_sexp)) ? TRUE : FALSE);
}

SEXP R_tuya_reconnect(SEXP dev_sexp) {
    return Rf_ScalarLogical(tuya_reconnect(get_device(dev_sexp)) ? TRUE : FALSE);
}

SEXP R_tuya_set_retry_limit(SEXP dev_sexp, SEXP limit) {
    tuya_set_retry_limit(get_device(dev_sexp), INTEGER(limit)[0]);
    return R_NilValue;
}

SEXP R_tuya_set_retry_delay(SEXP dev_sexp, SEXP delay_ms) {
    tuya_set_retry_delay(get_device(dev_sexp), INTEGER(delay_ms)[0]);
    return R_NilValue;
}

SEXP R_tuya_get_retry_limit(SEXP dev_sexp) {
    return Rf_ScalarInteger(tuya_get_retry_limit(get_device(dev_sexp)));
}

SEXP R_tuya_get_retry_delay(SEXP dev_sexp) {
    return Rf_ScalarInteger(tuya_get_retry_delay(get_device(dev_sexp)));
}

SEXP R_tuya_negotiate_session(SEXP dev_sexp, SEXP key) {
    bool ok = tuya_negotiate_session(get_device(dev_sexp),
                                     CHAR(STRING_ELT(key, 0)));
    return Rf_ScalarLogical(ok ? TRUE : FALSE);
}

SEXP R_tuya_negotiate_session_start(SEXP dev_sexp, SEXP key) {
    bool ok = tuya_negotiate_session_start(get_device(dev_sexp),
                                           CHAR(STRING_ELT(key, 0)));
    return Rf_ScalarLogical(ok ? TRUE : FALSE);
}

SEXP R_tuya_negotiate_session_finalize(SEXP dev_sexp, SEXP buf,
                                        SEXP key) {
    tuya_device_t *dev = get_device(dev_sexp);
    bool ok = tuya_negotiate_session_finalize(dev,
                (unsigned char *)RAW(buf), (int)LENGTH(buf),
                CHAR(STRING_ELT(key, 0)));
    return Rf_ScalarLogical(ok ? TRUE : FALSE);
}

SEXP R_tuya_get_protocol(SEXP dev_sexp) {
    return Rf_ScalarInteger((int)tuya_get_protocol(get_device(dev_sexp)));
}

SEXP R_tuya_get_session_state(SEXP dev_sexp) {
    return Rf_ScalarInteger((int)tuya_get_session_state(get_device(dev_sexp)));
}

SEXP R_tuya_get_socket_state(SEXP dev_sexp) {
    return Rf_ScalarInteger((int)tuya_get_socket_state(get_device(dev_sexp)));
}

SEXP R_tuya_get_last_error(SEXP dev_sexp) {
    return Rf_ScalarInteger(tuya_get_last_error(get_device(dev_sexp)));
}

SEXP R_tuya_set_async_mode(SEXP dev_sexp, SEXP async) {
    tuya_set_async_mode(get_device(dev_sexp), LOGICAL(async)[0] == TRUE);
    return R_NilValue;
}

SEXP R_tuya_is_socket_readable(SEXP dev_sexp) {
    return Rf_ScalarLogical(tuya_is_socket_readable(get_device(dev_sexp))
                            ? TRUE : FALSE);
}

SEXP R_tuya_is_socket_writable(SEXP dev_sexp) {
    return Rf_ScalarLogical(tuya_is_socket_writable(get_device(dev_sexp))
                            ? TRUE : FALSE);
}

SEXP R_tuya_set_session_ready(SEXP dev_sexp) {
    return Rf_ScalarLogical(tuya_set_session_ready(get_device(dev_sexp))
                            ? TRUE : FALSE);
}

SEXP R_tuya_build_message(SEXP dev_sexp, SEXP buf, SEXP cmd,
                           SEXP payload, SEXP key) {
    tuya_device_t *dev = get_device(dev_sexp);
    int sz = tuya_build_message(dev, (unsigned char *)RAW(buf),
                                 (enum tuya_command)INTEGER(cmd)[0],
                                 CHAR(STRING_ELT(payload, 0)),
                                 CHAR(STRING_ELT(key, 0)));
    return Rf_ScalarInteger(sz);
}

SEXP R_tuya_decode_message(SEXP dev_sexp, SEXP buf, SEXP key) {
    tuya_device_t *dev = get_device(dev_sexp);
    char *result = tuya_decode_message(dev, (unsigned char *)RAW(buf),
                                        (int)LENGTH(buf),
                                        CHAR(STRING_ELT(key, 0)));
    return take_string(result);
}

SEXP R_tuya_generate_payload(SEXP dev_sexp, SEXP cmd,
                              SEXP device_id, SEXP datapoints) {
    tuya_device_t *dev = get_device(dev_sexp);
    char *result = tuya_generate_payload(dev,
                    (enum tuya_command)INTEGER(cmd)[0],
                    CHAR(STRING_ELT(device_id, 0)),
                    CHAR(STRING_ELT(datapoints, 0)));
    return take_string(result);
}

SEXP R_tuya_send(SEXP dev_sexp, SEXP buf) {
    int sent = tuya_send(get_device(dev_sexp),
                          (unsigned char *)RAW(buf), (int)LENGTH(buf));
    return Rf_ScalarInteger(sent);
}

SEXP R_tuya_receive(SEXP dev_sexp, SEXP maxsize_sexp, SEXP minsize_sexp) {
    tuya_device_t *dev = get_device(dev_sexp);
    int maxsize = INTEGER(maxsize_sexp)[0];
    int minsize = INTEGER(minsize_sexp)[0];
    unsigned char *buf = (unsigned char *)R_alloc(maxsize, 1);
    int got = tuya_receive(dev, buf, maxsize, minsize);
    if (got < 0) return R_NilValue;
    SEXP result = PROTECT(NEW_RAW(got));
    memcpy(RAW(result), buf, (size_t)got);
    UNPROTECT(1);
    return result;
}

SEXP R_tuya_set_device22(SEXP dev_sexp, SEXP null_dps_json) {
    tuya_device_t *dev = get_device(dev_sexp);
    const char *json = (STRING_ELT(null_dps_json, 0) == NA_STRING)
                        ? NULL : CHAR(STRING_ELT(null_dps_json, 0));
    tuya_set_device22(dev, json);
    return R_NilValue;
}

SEXP R_tuya_is_device22(SEXP dev_sexp) {
    return Rf_ScalarLogical(tuya_is_device22(get_device(dev_sexp))
                            ? TRUE : FALSE);
}

SEXP R_tuya_set_value_bool(SEXP dev_sexp, SEXP dp, SEXP value) {
    tuya_device_t *dev = get_device(dev_sexp);
    bool v = LOGICAL(value)[0] == TRUE;
    return take_string(tuya_set_value_bool(dev, INTEGER(dp)[0], v));
}

SEXP R_tuya_set_value_int(SEXP dev_sexp, SEXP dp, SEXP value) {
    return take_string(tuya_set_value_int(get_device(dev_sexp),
                       INTEGER(dp)[0], INTEGER(value)[0]));
}

SEXP R_tuya_set_value_string(SEXP dev_sexp, SEXP dp, SEXP value) {
    return take_string(tuya_set_value_string(get_device(dev_sexp),
                       INTEGER(dp)[0], CHAR(STRING_ELT(value, 0))));
}

SEXP R_tuya_set_value_float(SEXP dev_sexp, SEXP dp, SEXP value) {
    return take_string(tuya_set_value_float(get_device(dev_sexp),
                       INTEGER(dp)[0], REAL(value)[0]));
}

SEXP R_tuya_turn_on(SEXP dev_sexp, SEXP switch_dp) {
    return take_string(tuya_turn_on(get_device(dev_sexp),
                                    INTEGER(switch_dp)[0]));
}

SEXP R_tuya_turn_off(SEXP dev_sexp, SEXP switch_dp) {
    return take_string(tuya_turn_off(get_device(dev_sexp),
                                     INTEGER(switch_dp)[0]));
}

SEXP R_tuya_status(SEXP dev_sexp) {
    return take_string(tuya_status(get_device(dev_sexp)));
}

SEXP R_tuya_heartbeat(SEXP dev_sexp) {
    return take_string(tuya_heartbeat(get_device(dev_sexp)));
}
