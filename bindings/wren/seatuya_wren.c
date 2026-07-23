/*
 * seatuya_wren.c -- Wren foreign method implementations for libseatuya
 *
 * Compile and link into your Wren host program:
 *   cc -c -I/usr/local/include seatuya_wren.c
 *   cc -o my_host my_host.c seatuya_wren.o -lseatuya
 *
 * Then register `seatuyaBindForeignClass` and `seatuyaBindForeignMethod`
 * with your Wren VM configuration.
 *
 *   config.bindForeignClassFn = seatuyaBindForeignClass;
 *   config.bindForeignMethodFn = seatuyaBindForeignMethod;
 */

#include <string.h>
#include <stdlib.h>

#include "wren.h"
#include "seatuya.h"

/* ------------------------------------------------------------------ */
/*  Helpers                                                            */
/* ------------------------------------------------------------------ */

/* Retrieve tuya_device_t* from a Device foreign instance at slot `s`. */
#define DEV_PTR(vm, s) (*(tuya_device_t**)wrenGetSlotForeign(vm, s))

/* Convenience: consume a malloc'd C string into a Wren string (slot 0)
 * and free the C buffer.  If ptr is NULL sets slot to null. */
static void set_consumed(WrenVM *vm, char *ptr) {
    if (ptr) {
        wrenSetSlotString(vm, 0, ptr);
        tuya_free_string(ptr);
    } else {
        wrenSetSlotNull(vm, 0);
    }
}

/* ------------------------------------------------------------------ */
/*  Allocate / finalize                                                */
/* ------------------------------------------------------------------ */

static void device_allocate(WrenVM *vm) {
    /* The foreign data is already allocated by Wren; initialise to NULL
     * so that if the constructor fails we don't finalise garbage. */
    tuya_device_t **slot = (tuya_device_t **)wrenGetSlotForeign(vm, 0);
    *slot = NULL;
}

static void device_finalize(void *data) {
    tuya_device_t **ptr = (tuya_device_t **)data;
    if (*ptr) {
        tuya_destroy(*ptr);
        *ptr = NULL;
    }
}

/* ------------------------------------------------------------------ */
/*  Static methods                                                     */
/* ------------------------------------------------------------------ */

/* seatuya.Device.version() -> String */
static void device_static_version(WrenVM *vm) {
    wrenSetSlotString(vm, 0, tuya_version());
}

/* seatuya.Device.create(devId, addr, key, ver) -> Device | null */
static void device_static_create(WrenVM *vm) {
    const char *dev_id = wrenGetSlotString(vm, 2);
    const char *addr   = wrenGetSlotString(vm, 3);
    const char *key    = wrenGetSlotString(vm, 4);
    const char *ver    = wrenGetSlotString(vm, 5);

    tuya_device_t *dev = tuya_create(dev_id, addr, key, ver);
    if (!dev) {
        wrenSetSlotNull(vm, 0);
        return;
    }

    /* Slot 1 holds the Device class – use it to create a new foreign
     * instance in slot 0 (the return slot). */
    tuya_device_t **data = (tuya_device_t **)
        wrenSetSlotNewForeign(vm, 0, 1, sizeof(tuya_device_t *));
    *data = dev;
}

/* seatuya.Device.alloc(ver) -> Device | null */
static void device_static_alloc(WrenVM *vm) {
    const char *ver = wrenGetSlotString(vm, 2);

    tuya_device_t *dev = tuya_alloc(ver);
    if (!dev) {
        wrenSetSlotNull(vm, 0);
        return;
    }

    tuya_device_t **data = (tuya_device_t **)
        wrenSetSlotNewForeign(vm, 0, 1, sizeof(tuya_device_t *));
    *data = dev;
}

/* ------------------------------------------------------------------ */
/*  Instance methods: lifecycle                                        */
/* ------------------------------------------------------------------ */

static void device_destroy(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (dev) {
        DEV_PTR(vm, 0) = NULL;  /* prevent finalize from double-freeing */
        tuya_destroy(dev);
    }
    wrenSetSlotNull(vm, 0);
}

/* ------------------------------------------------------------------ */
/*  Instance methods: credentials                                      */
/* ------------------------------------------------------------------ */

static void device_set_credentials(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    const char *dev_id = wrenGetSlotString(vm, 1);
    const char *key    = wrenGetSlotString(vm, 2);
    tuya_set_credentials(dev, dev_id, key);
    wrenSetSlotNull(vm, 0);
}

static void device_get_device_id(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    const char *s = tuya_get_device_id(dev);
    wrenSetSlotString(vm, 0, s ? s : "");
}

static void device_get_local_key(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    const char *s = tuya_get_local_key(dev);
    wrenSetSlotString(vm, 0, s ? s : "");
}

static void device_get_ip(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    const char *s = tuya_get_ip(dev);
    wrenSetSlotString(vm, 0, s ? s : "");
}

/* ------------------------------------------------------------------ */
/*  Instance methods: connection                                       */
/* ------------------------------------------------------------------ */

static void device_connect(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotBool(vm, 0, false); return; }
    const char *host = wrenGetSlotString(vm, 1);
    wrenSetSlotBool(vm, 0, tuya_connect(dev, host));
}

static void device_disconnect(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (dev) tuya_disconnect(dev);
    wrenSetSlotNull(vm, 0);
}

static void device_is_connected(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotBool(vm, 0, dev ? tuya_is_connected(dev) : false);
}

static void device_reconnect(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotBool(vm, 0, dev ? tuya_reconnect(dev) : false);
}

/* ------------------------------------------------------------------ */
/*  Instance methods: retry settings                                   */
/* ------------------------------------------------------------------ */

static void device_set_retry_limit(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int lim = (int)wrenGetSlotDouble(vm, 1);
    tuya_set_retry_limit(dev, lim);
    wrenSetSlotNull(vm, 0);
}

static void device_set_retry_delay(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int ms = (int)wrenGetSlotDouble(vm, 1);
    tuya_set_retry_delay(dev, ms);
    wrenSetSlotNull(vm, 0);
}

static void device_get_retry_limit(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotDouble(vm, 0, dev ? tuya_get_retry_limit(dev) : 0);
}

static void device_get_retry_delay(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotDouble(vm, 0, dev ? tuya_get_retry_delay(dev) : 0);
}

/* ------------------------------------------------------------------ */
/*  Instance methods: session                                          */
/* ------------------------------------------------------------------ */

static void device_negotiate_session(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotBool(vm, 0, false); return; }
    const char *key = wrenGetSlotString(vm, 1);
    wrenSetSlotBool(vm, 0, tuya_negotiate_session(dev, key));
}

static void device_negotiate_session_start(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotBool(vm, 0, false); return; }
    const char *key = wrenGetSlotString(vm, 1);
    wrenSetSlotBool(vm, 0, tuya_negotiate_session_start(dev, key));
}

static void device_negotiate_session_finalize(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotBool(vm, 0, false); return; }
    /* buf is passed as a Wren string; we use the byte length from Wren's
     * internal string representation.  strlen() is used as a fallback. */
    /* NOTE: for binary data containing NUL bytes, use the low-level C API
     * directly, or encode data in a NUL-free format (e.g. base64). */
    const char *buf = wrenGetSlotString(vm, 1);
    int size = (int)strlen(buf);
    const char *key = wrenGetSlotString(vm, 2);
    wrenSetSlotBool(vm, 0,
        tuya_negotiate_session_finalize(dev, (unsigned char *)buf, size, key));
}

/* ------------------------------------------------------------------ */
/*  Instance methods: state queries                                    */
/* ------------------------------------------------------------------ */

static void device_get_protocol(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotDouble(vm, 0, dev ? (double)tuya_get_protocol(dev) : -1);
}

static void device_get_session_state(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotDouble(vm, 0, dev ? (double)tuya_get_session_state(dev) : -1);
}

static void device_get_socket_state(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotDouble(vm, 0, dev ? (double)tuya_get_socket_state(dev) : -1);
}

static void device_get_last_error(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotDouble(vm, 0, dev ? (double)tuya_get_last_error(dev) : -1);
}

/* ------------------------------------------------------------------ */
/*  Instance methods: async mode                                       */
/* ------------------------------------------------------------------ */

static void device_set_async_mode(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    bool async = wrenGetSlotBool(vm, 1);
    tuya_set_async_mode(dev, async);
    wrenSetSlotNull(vm, 0);
}

static void device_is_socket_readable(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotBool(vm, 0, dev ? tuya_is_socket_readable(dev) : false);
}

static void device_is_socket_writable(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotBool(vm, 0, dev ? tuya_is_socket_writable(dev) : false);
}

static void device_set_session_ready(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotBool(vm, 0, dev ? tuya_set_session_ready(dev) : false);
}

/* ------------------------------------------------------------------ */
/*  Instance methods: message building / decoding / payload            */
/* ------------------------------------------------------------------ */

static void device_build_message(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int cmd = (int)wrenGetSlotDouble(vm, 1);
    const char *payload = wrenGetSlotString(vm, 2);
    const char *key = wrenGetSlotString(vm, 3);

    unsigned char buf[1024];
    int n = tuya_build_message(dev, buf, (enum tuya_command)cmd, payload, key);
    if (n < 0) { wrenSetSlotNull(vm, 0); return; }

    wrenSetSlotBytes(vm, 0, (const char *)buf, (size_t)n);
}

static void device_decode_message(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    /* Input buffer as Wren string (see note about NUL bytes above). */
    const unsigned char *buf = (const unsigned char *)wrenGetSlotString(vm, 1);
    int size = (int)strlen((const char *)buf);
    const char *key = wrenGetSlotString(vm, 2);

    set_consumed(vm, tuya_decode_message(dev, (unsigned char *)buf, size, key));
}

static void device_generate_payload(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int cmd = (int)wrenGetSlotDouble(vm, 1);
    const char *dev_id = wrenGetSlotString(vm, 2);
    const char *dps = wrenGetSlotString(vm, 3);

    set_consumed(vm,
        tuya_generate_payload(dev, (enum tuya_command)cmd, dev_id, dps));
}

/* ------------------------------------------------------------------ */
/*  Instance methods: raw send / receive                               */
/* ------------------------------------------------------------------ */

static void device_send(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotDouble(vm, 0, -1); return; }
    const unsigned char *buf = (const unsigned char *)wrenGetSlotString(vm, 1);
    int size = (int)strlen((const char *)buf);

    int sent = tuya_send(dev, (unsigned char *)buf, size);
    wrenSetSlotDouble(vm, 0, (double)sent);
}

static void device_receive(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int maxsize = (int)wrenGetSlotDouble(vm, 1);
    int minsize = (int)wrenGetSlotDouble(vm, 2);

    unsigned char *buf = (unsigned char *)malloc((size_t)maxsize);
    if (!buf) { wrenSetSlotNull(vm, 0); return; }

    int got = tuya_receive(dev, buf, maxsize, minsize);
    if (got < 0) {
        free(buf);
        wrenSetSlotNull(vm, 0);
        return;
    }

    wrenSetSlotBytes(vm, 0, (const char *)buf, (size_t)got);
    free(buf);
}

/* ------------------------------------------------------------------ */
/*  Instance methods: device22                                         */
/* ------------------------------------------------------------------ */

static void device_set_device22(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    const char *json = wrenGetSlotString(vm, 1);
    tuya_set_device22(dev, json);
    wrenSetSlotNull(vm, 0);
}

static void device_is_device22(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    wrenSetSlotBool(vm, 0, dev && tuya_is_device22(dev));
}

/* ------------------------------------------------------------------ */
/*  Instance methods: high-level round-trip                            */
/* ------------------------------------------------------------------ */

static void device_set_value_bool(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int dp = (int)wrenGetSlotDouble(vm, 1);
    bool val = wrenGetSlotBool(vm, 2);
    set_consumed(vm, tuya_set_value_bool(dev, dp, val));
}

static void device_set_value_int(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int dp = (int)wrenGetSlotDouble(vm, 1);
    int val = (int)wrenGetSlotDouble(vm, 2);
    set_consumed(vm, tuya_set_value_int(dev, dp, val));
}

static void device_set_value_string(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int dp = (int)wrenGetSlotDouble(vm, 1);
    const char *val = wrenGetSlotString(vm, 2);
    set_consumed(vm, tuya_set_value_string(dev, dp, val));
}

static void device_set_value_float(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int dp = (int)wrenGetSlotDouble(vm, 1);
    double val = wrenGetSlotDouble(vm, 2);
    set_consumed(vm, tuya_set_value_float(dev, dp, val));
}

static void device_turn_on(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int dp = (int)wrenGetSlotDouble(vm, 1);
    set_consumed(vm, tuya_turn_on(dev, dp));
}

static void device_turn_off(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    int dp = (int)wrenGetSlotDouble(vm, 1);
    set_consumed(vm, tuya_turn_off(dev, dp));
}

static void device_status(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    set_consumed(vm, tuya_status(dev));
}

static void device_heartbeat(WrenVM *vm) {
    tuya_device_t *dev = DEV_PTR(vm, 0);
    if (!dev) { wrenSetSlotNull(vm, 0); return; }
    set_consumed(vm, tuya_heartbeat(dev));
}

/* ------------------------------------------------------------------ */
/*  Registration callbacks                                             */
/* ------------------------------------------------------------------ */

WrenForeignClassMethods seatuyaBindForeignClass(
    WrenVM *vm, const char *module, const char *className)
{
    WrenForeignClassMethods methods = { NULL, NULL };
    if (strcmp(module, "seatuya") == 0 && strcmp(className, "Device") == 0) {
        methods.allocate = device_allocate;
        methods.finalize = device_finalize;
    }
    return methods;
}

WrenForeignMethodFn seatuyaBindForeignMethod(
    WrenVM *vm, const char *module, const char *className,
    bool isStatic, const char *signature)
{
    if (strcmp(module, "seatuya") != 0) return NULL;

    if (strcmp(className, "Device") == 0) {
        if (isStatic) {
            if (strcmp(signature, "version()") == 0)
                return device_static_version;
            if (strcmp(signature, "create(_,_,_,_)") == 0)
                return device_static_create;
            if (strcmp(signature, "alloc(_)") == 0)
                return device_static_alloc;
        } else {
            /* Lifecycle */
            if (strcmp(signature, "destroy()") == 0)
                return device_destroy;
            /* Credentials */
            if (strcmp(signature, "setCredentials(_,_)") == 0)
                return device_set_credentials;
            if (strcmp(signature, "getDeviceId()") == 0)
                return device_get_device_id;
            if (strcmp(signature, "getLocalKey()") == 0)
                return device_get_local_key;
            if (strcmp(signature, "getIp()") == 0)
                return device_get_ip;
            /* Connection */
            if (strcmp(signature, "connect(_)") == 0)
                return device_connect;
            if (strcmp(signature, "disconnect()") == 0)
                return device_disconnect;
            if (strcmp(signature, "isConnected()") == 0)
                return device_is_connected;
            if (strcmp(signature, "reconnect()") == 0)
                return device_reconnect;
            /* Retry */
            if (strcmp(signature, "setRetryLimit(_)") == 0)
                return device_set_retry_limit;
            if (strcmp(signature, "setRetryDelay(_)") == 0)
                return device_set_retry_delay;
            if (strcmp(signature, "getRetryLimit()") == 0)
                return device_get_retry_limit;
            if (strcmp(signature, "getRetryDelay()") == 0)
                return device_get_retry_delay;
            /* Session */
            if (strcmp(signature, "negotiateSession(_)") == 0)
                return device_negotiate_session;
            if (strcmp(signature, "negotiateSessionStart(_)") == 0)
                return device_negotiate_session_start;
            if (strcmp(signature, "negotiateSessionFinalize(_,_)") == 0)
                return device_negotiate_session_finalize;
            /* State */
            if (strcmp(signature, "getProtocol()") == 0)
                return device_get_protocol;
            if (strcmp(signature, "getSessionState()") == 0)
                return device_get_session_state;
            if (strcmp(signature, "getSocketState()") == 0)
                return device_get_socket_state;
            if (strcmp(signature, "getLastError()") == 0)
                return device_get_last_error;
            /* Async */
            if (strcmp(signature, "setAsyncMode(_)") == 0)
                return device_set_async_mode;
            if (strcmp(signature, "isSocketReadable()") == 0)
                return device_is_socket_readable;
            if (strcmp(signature, "isSocketWritable()") == 0)
                return device_is_socket_writable;
            if (strcmp(signature, "setSessionReady()") == 0)
                return device_set_session_ready;
            /* Message building / decoding */
            if (strcmp(signature, "buildMessage(_,_,_)") == 0)
                return device_build_message;
            if (strcmp(signature, "decodeMessage(_,_)") == 0)
                return device_decode_message;
            if (strcmp(signature, "generatePayload(_,_,_)") == 0)
                return device_generate_payload;
            /* Raw send/receive */
            if (strcmp(signature, "send(_)") == 0)
                return device_send;
            if (strcmp(signature, "receive(_,_)") == 0)
                return device_receive;
            /* device22 */
            if (strcmp(signature, "setDevice22(_)") == 0)
                return device_set_device22;
            if (strcmp(signature, "isDevice22()") == 0)
                return device_is_device22;
            /* High-level round-trip */
            if (strcmp(signature, "setValueBool(_,_)") == 0)
                return device_set_value_bool;
            if (strcmp(signature, "setValueInt(_,_)") == 0)
                return device_set_value_int;
            if (strcmp(signature, "setValueString(_,_)") == 0)
                return device_set_value_string;
            if (strcmp(signature, "setValueFloat(_,_)") == 0)
                return device_set_value_float;
            if (strcmp(signature, "turnOn(_)") == 0)
                return device_turn_on;
            if (strcmp(signature, "turnOff(_)") == 0)
                return device_turn_off;
            if (strcmp(signature, "status()") == 0)
                return device_status;
            if (strcmp(signature, "heartbeat()") == 0)
                return device_heartbeat;
        }
    }
    return NULL;
}
