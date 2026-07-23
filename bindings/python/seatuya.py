"""seatuya.py — Python ctypes bindings for libseatuya.

Pure Python binding using the standard library ctypes module.
No external dependencies.

Usage:
    import seatuya
    dev = seatuya.create(device_id, "192.168.1.100", local_key, "3.4")
    print(seatuya.turn_on(dev, 1))
    print(seatuya.status(dev))
    seatuya.destroy(dev)
"""

import ctypes
import ctypes.util
import os
import sys
from enum import IntEnum

# ── Library discovery ──
_lib_name = os.environ.get("SEATUYA_LIB")
if not _lib_name:
    if sys.platform == "darwin":
        _lib_name = "libseatuya.dylib"
    elif sys.platform == "win32":
        _lib_name = "seatuya.dll"
    else:
        _lib_name = "libseatuya.so"

_lib = ctypes.cdll.LoadLibrary(_lib_name)

# ── Type definitions ──
_c_bool = ctypes.c_bool
_c_int = ctypes.c_int
_c_double = ctypes.c_double
_c_char_p = ctypes.c_char_p
_c_void_p = ctypes.c_void_p

# ── Function signatures ──
_lib.tuya_version.restype = _c_char_p

_lib.tuya_create.argtypes = [_c_char_p, _c_char_p, _c_char_p, _c_char_p]
_lib.tuya_create.restype = _c_void_p

_lib.tuya_alloc.argtypes = [_c_char_p]
_lib.tuya_alloc.restype = _c_void_p

_lib.tuya_destroy.argtypes = [_c_void_p]
_lib.tuya_destroy.restype = None

_lib.tuya_set_credentials.argtypes = [_c_void_p, _c_char_p, _c_char_p]
_lib.tuya_set_credentials.restype = None

_lib.tuya_get_device_id.argtypes = [_c_void_p]
_lib.tuya_get_device_id.restype = _c_char_p

_lib.tuya_get_local_key.argtypes = [_c_void_p]
_lib.tuya_get_local_key.restype = _c_char_p

_lib.tuya_get_ip.argtypes = [_c_void_p]
_lib.tuya_get_ip.restype = _c_char_p

_lib.tuya_connect.argtypes = [_c_void_p, _c_char_p]
_lib.tuya_connect.restype = _c_bool

_lib.tuya_disconnect.argtypes = [_c_void_p]
_lib.tuya_disconnect.restype = None

_lib.tuya_is_connected.argtypes = [_c_void_p]
_lib.tuya_is_connected.restype = _c_bool

_lib.tuya_reconnect.argtypes = [_c_void_p]
_lib.tuya_reconnect.restype = _c_bool

_lib.tuya_set_retry_limit.argtypes = [_c_void_p, _c_int]
_lib.tuya_set_retry_delay.argtypes = [_c_void_p, _c_int]
_lib.tuya_get_retry_limit.argtypes = [_c_void_p]
_lib.tuya_get_retry_limit.restype = _c_int
_lib.tuya_get_retry_delay.argtypes = [_c_void_p]
_lib.tuya_get_retry_delay.restype = _c_int

_lib.tuya_negotiate_session.argtypes = [_c_void_p, _c_char_p]
_lib.tuya_negotiate_session.restype = _c_bool

_lib.tuya_negotiate_session_start.argtypes = [_c_void_p, _c_char_p]
_lib.tuya_negotiate_session_start.restype = _c_bool

_lib.tuya_negotiate_session_finalize.argtypes = [_c_void_p, _c_void_p, _c_int, _c_char_p]
_lib.tuya_negotiate_session_finalize.restype = _c_bool

_lib.tuya_get_protocol.argtypes = [_c_void_p]
_lib.tuya_get_protocol.restype = _c_int
_lib.tuya_get_session_state.argtypes = [_c_void_p]
_lib.tuya_get_session_state.restype = _c_int
_lib.tuya_get_socket_state.argtypes = [_c_void_p]
_lib.tuya_get_socket_state.restype = _c_int
_lib.tuya_get_last_error.argtypes = [_c_void_p]
_lib.tuya_get_last_error.restype = _c_int

_lib.tuya_set_async_mode.argtypes = [_c_void_p, _c_bool]
_lib.tuya_is_socket_readable.argtypes = [_c_void_p]
_lib.tuya_is_socket_readable.restype = _c_bool
_lib.tuya_is_socket_writable.argtypes = [_c_void_p]
_lib.tuya_is_socket_writable.restype = _c_bool
_lib.tuya_set_session_ready.argtypes = [_c_void_p]
_lib.tuya_set_session_ready.restype = _c_bool

_lib.tuya_build_message.argtypes = [_c_void_p, _c_void_p, _c_int, _c_char_p, _c_char_p]
_lib.tuya_build_message.restype = _c_int

_lib.tuya_decode_message.argtypes = [_c_void_p, _c_void_p, _c_int, _c_char_p]
_lib.tuya_decode_message.restype = _c_char_p

_lib.tuya_generate_payload.argtypes = [_c_void_p, _c_int, _c_char_p, _c_char_p]
_lib.tuya_generate_payload.restype = _c_char_p

_lib.tuya_send.argtypes = [_c_void_p, _c_void_p, _c_int]
_lib.tuya_send.restype = _c_int
_lib.tuya_receive.argtypes = [_c_void_p, _c_void_p, _c_int, _c_int]
_lib.tuya_receive.restype = _c_int

_lib.tuya_set_value_bool.argtypes = [_c_void_p, _c_int, _c_bool]
_lib.tuya_set_value_bool.restype = _c_char_p
_lib.tuya_set_value_int.argtypes = [_c_void_p, _c_int, _c_int]
_lib.tuya_set_value_int.restype = _c_char_p
_lib.tuya_set_value_string.argtypes = [_c_void_p, _c_int, _c_char_p]
_lib.tuya_set_value_string.restype = _c_char_p
_lib.tuya_set_value_float.argtypes = [_c_void_p, _c_int, _c_double]
_lib.tuya_set_value_float.restype = _c_char_p

_lib.tuya_turn_on.argtypes = [_c_void_p, _c_int]
_lib.tuya_turn_on.restype = _c_char_p
_lib.tuya_turn_off.argtypes = [_c_void_p, _c_int]
_lib.tuya_turn_off.restype = _c_char_p
_lib.tuya_status.argtypes = [_c_void_p]
_lib.tuya_status.restype = _c_char_p
_lib.tuya_heartbeat.argtypes = [_c_void_p]
_lib.tuya_heartbeat.restype = _c_char_p

_lib.tuya_free_string.argtypes = [_c_char_p]
_lib.tuya_free_string.restype = None

_lib.tuya_set_device22.argtypes = [_c_void_p, _c_char_p]
_lib.tuya_is_device22.argtypes = [_c_void_p]
_lib.tuya_is_device22.restype = _c_bool

# ── Enums ──
class Command(IntEnum):
    UDP = 0; AP_CONFIG = 1; ACTIVE = 2; BIND = 3; RENAME_GW = 4
    RENAME_DEVICE = 5; UNBIND = 6; CONTROL = 7; STATUS = 8; HEART_BEAT = 9
    DP_QUERY = 10; QUERY_WIFI = 11; TOKEN_BIND = 12; CONTROL_NEW = 13
    ENABLE_WIFI = 14; DP_QUERY_NEW = 16; SCENE_EXECUTE = 17; UPDATEDPS = 18
    UDP_NEW = 19; AP_CONFIG_NEW = 20; GET_LOCAL_TIME = 28; WEATHER_OPEN = 32
    WEATHER_DATA = 33; STATE_UPLOAD_SYN = 34; STATE_UPLOAD_SYN_RECV = 35
    HEART_BEAT_STOP = 37; STREAM_TRANS = 38; GET_WIFI_STATUS = 43
    WIFI_CONNECT_TEST = 44; GET_MAC = 45; GET_IR_STATUS = 46; IR_TX_RX_TEST = 47
    LAN_GW_ACTIVE = 240; LAN_SUB_DEV_REQUEST = 241; LAN_DELETE_SUB_DEV = 242
    LAN_REPORT_SUB_DEV = 243; LAN_SCENE = 244; LAN_PUBLISH_CLOUD_CONFIG = 245
    LAN_PUBLISH_APP_CONFIG = 246; LAN_EXPORT_APP_CONFIG = 247
    LAN_PUBLISH_SCENE_PANEL = 248; LAN_REMOVE_GW = 249; LAN_CHECK_GW_UPDATE = 250
    LAN_GW_UPDATE = 251; LAN_SET_GW_CHANNEL = 252

class Protocol(IntEnum): V31 = 0; V33 = 1; V34 = 2; V35 = 3
class SessionState(IntEnum): INVALID = 0; STARTING = 1; FINALIZING = 2; ESTABLISHED = 3
class SocketState(IntEnum): NO_SUCH_HOST = 0; NO_SOCK_AVAIL = 1; FAILED = 2; DISCONNECTED = 3; CONNECTING = 4; CONNECTED = 5; READY = 6; RECEIVING = 7

DEFAULT_PORT = 6668
BUFSIZE = 1024
DEFAULT_RETRY_LIMIT = 5
DEFAULT_RETRY_DELAY_MS = 100

# ── Convenience wrappers ──
def version(): return _lib.tuya_version().decode() if _lib.tuya_version() else None

def create(device_id, address, local_key, ver):
    return _lib.tuya_create(
        device_id.encode(), address.encode(), local_key.encode(), ver.encode())

def alloc(ver):
    return _lib.tuya_alloc(ver.encode())

def destroy(dev): _lib.tuya_destroy(dev)

def set_credentials(dev, device_id, local_key):
    _lib.tuya_set_credentials(dev, device_id.encode(), local_key.encode())

def get_device_id(dev):
    r = _lib.tuya_get_device_id(dev); return r.decode() if r else None

def get_local_key(dev):
    r = _lib.tuya_get_local_key(dev); return r.decode() if r else None

def get_ip(dev):
    r = _lib.tuya_get_ip(dev); return r.decode() if r else None

def connect(dev, hostname):
    return _lib.tuya_connect(dev, hostname.encode())

def disconnect(dev): _lib.tuya_disconnect(dev)
def is_connected(dev): return _lib.tuya_is_connected(dev)
def reconnect(dev): return _lib.tuya_reconnect(dev)

def set_retry_limit(dev, limit): _lib.tuya_set_retry_limit(dev, limit)
def set_retry_delay(dev, ms): _lib.tuya_set_retry_delay(dev, ms)
def get_retry_limit(dev): return _lib.tuya_get_retry_limit(dev)
def get_retry_delay(dev): return _lib.tuya_get_retry_delay(dev)

def negotiate_session(dev, key):
    return _lib.tuya_negotiate_session(dev, key.encode())

def get_protocol(dev): return Protocol(_lib.tuya_get_protocol(dev))
def get_session_state(dev): return SessionState(_lib.tuya_get_session_state(dev))
def get_socket_state(dev): return SocketState(_lib.tuya_get_socket_state(dev))
def get_last_error(dev): return _lib.tuya_get_last_error(dev)

def set_async_mode(dev, flag): _lib.tuya_set_async_mode(dev, flag)
def is_socket_readable(dev): return _lib.tuya_is_socket_readable(dev)
def is_socket_writable(dev): return _lib.tuya_is_socket_writable(dev)
def set_session_ready(dev): return _lib.tuya_set_session_ready(dev)

def _consume_str(ptr):
    if not ptr: return None
    s = ptr.decode()
    _lib.tuya_free_string(ptr)
    return s

def set_value(dev, dp, value):
    if isinstance(value, bool):
        ptr = _lib.tuya_set_value_bool(dev, dp, value)
    elif isinstance(value, int):
        ptr = _lib.tuya_set_value_int(dev, dp, value)
    elif isinstance(value, float):
        ptr = _lib.tuya_set_value_float(dev, dp, value)
    else:
        ptr = _lib.tuya_set_value_string(dev, dp, str(value).encode())
    return _consume_str(ptr)

def turn_on(dev, switch_dp=1):
    return _consume_str(_lib.tuya_turn_on(dev, switch_dp))

def turn_off(dev, switch_dp=1):
    return _consume_str(_lib.tuya_turn_off(dev, switch_dp))

def status(dev):
    return _consume_str(_lib.tuya_status(dev))

def heartbeat(dev):
    return _consume_str(_lib.tuya_heartbeat(dev))

def set_device22(dev, null_dps_json):
    _lib.tuya_set_device22(dev, null_dps_json.encode() if null_dps_json else None)

def is_device22(dev):
    return _lib.tuya_is_device22(dev)

# Low-level
def build_message(dev, cmd, payload, key):
    buf = ctypes.create_string_buffer(BUFSIZE)
    n = _lib.tuya_build_message(dev, buf, cmd, payload.encode(), key.encode())
    return buf.raw[:n] if n > 0 else None

def decode_message(dev, buf, key):
    return _consume_str(_lib.tuya_decode_message(dev, buf, len(buf), key.encode()))

def generate_payload(dev, cmd, device_id, datapoints=""):
    return _consume_str(_lib.tuya_generate_payload(dev, cmd, device_id.encode(), datapoints.encode()))

def send_frame(dev, buf):
    return _lib.tuya_send(dev, buf, len(buf))

def receive_frame(dev, maxsize=BUFSIZE, minsize=0):
    buf = ctypes.create_string_buffer(maxsize)
    n = _lib.tuya_receive(dev, buf, maxsize, minsize)
    return buf.raw[:n] if n > 0 else None
